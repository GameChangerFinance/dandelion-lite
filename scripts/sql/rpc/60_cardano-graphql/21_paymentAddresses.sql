/* === Composite types ========================================= */

DROP TYPE IF EXISTS "cardano_graphql"."PaymentAddress" CASCADE;
DROP TYPE IF EXISTS "cardano_graphql"."PaymentAddressSummary" CASCADE;
DROP TYPE IF EXISTS "cardano_graphql"."AssetBalance" CASCADE; 

CREATE TYPE  "cardano_graphql"."AssetBalance" AS (
  address  varchar,
  ident    bigint,
  quantity numeric -- SAFETY: was public.word64type; sums can exceed 2^64-1, use unbounded numeric
);

CREATE TYPE "cardano_graphql"."PaymentAddressSummary" AS (
  "assetBalances" "cardano_graphql"."AssetBalance"[], -- list of balances for this address
  "utxosCount"    bigint,                             -- number of utxos for this address. SAFETY: was integer; COUNT(*) returns bigint and can exceed int
  "assetCount"    bigint                              -- number of rows in "assetBalances" for this address. SAFETY: was integer; number of assets can exceed int in large wallets
);

CREATE TYPE "cardano_graphql"."PaymentAddress" AS (
  address varchar,
  summary "cardano_graphql"."PaymentAddressSummary"
);


/* === Optimized function ================================================ */

CREATE OR REPLACE FUNCTION "cardano_graphql"."getPaymentAddresses"(
  addresses varchar[],                      -- must contain at least 1 item
  "atBlock"   public.word31type DEFAULT NULL  -- optional (inclusive)
)
RETURNS SETOF "cardano_graphql"."PaymentAddress"
LANGUAGE sql
STABLE
AS $func$
  /*
    Performance approach
    --------------------
    - Branch the UTXO source so we NEVER touch Transaction/Block when atBlock IS NULL.
      (The WHERE atBlock IS NULL / IS NOT NULL predicates are mutually exclusive, so
       the executor only runs one branch.)
    - Aggregate ADA (sum(value)) and UTXO count together in one pass.
    - Aggregate tokens once, then pack them into arrays without ORDER BY.
      (We concatenate ADA row + token array ⇒ ADA appears first without sorting.)
    - Avoid duplicated GROUP BY scans and avoid UNION/ORDER in array_agg.
  */

  WITH
  /* 0) Distinct, non-null input addresses so we can still return rows for
        addresses with zero UTXOs (ADA = 0, "utxosCount" = 0, no tokens). */
  input_addresses AS (
    SELECT DISTINCT a::varchar AS address
    FROM unnest(addresses) AS t(a)
    WHERE a IS NOT NULL
  ),

  /* 1) UTXOs filtered by optional atBlock.
        - If atBlock IS NULL: take UTXOs by address directly (fast path).
        - If atBlock IS NOT NULL: additionally enforce b.number <= atBlock
          via EXISTS over (tx → block).
        NOTE: The two branches are mutually exclusive; only one executes. */
  utxos AS (
    -- Fast path (no block/tx lookup at all)
    SELECT u.id, u.address, u.value
    FROM   "cardano_graphql"."Utxo" u
    WHERE  "atBlock" IS NULL
       AND u."address" IN (SELECT address FROM input_addresses)

    UNION ALL

    -- Filtered path (only when atBlock IS NOT NULL)
    SELECT u.id, u.address, u.value
    FROM   "cardano_graphql"."Utxo" u
    WHERE  "atBlock" IS NOT NULL
       AND u."address" IN (SELECT address FROM input_addresses)
       AND EXISTS (
             SELECT 1
             FROM "cardano_graphql"."Transaction" tx
             WHERE tx."hash" = u."txHash"
               AND EXISTS (
                     SELECT 1
                     FROM "cardano_graphql"."Block" b
                     WHERE b."hash" = tx."blockHash"
                       AND b."number" <= "atBlock"
                   )
           )
  ),

  /* 2) ADA sums and UTXO counts together (one pass). LEFT JOIN keeps rows
        for addresses with no UTXOs (ADA = 0, count = 0). */
  ada_and_counts AS (
    SELECT
      ia.address,
      COALESCE(SUM(u.value), 0)             AS ada_quantity, -- SAFETY: removed ::public.word64type; keep as numeric
      COUNT(u.id)                           AS utxos_count    -- SAFETY: removed ::int; COUNT is bigint
    FROM input_addresses ia
    LEFT JOIN utxos u ON u.address = ia.address
    GROUP BY ia.address
  ),

  /* 3) Token sums per (address, ident). Only addresses present in UTXOs
        appear here. */
  token_sums AS (
    SELECT
      u.address::varchar                    AS address,
      mao.ident::bigint                     AS ident,
      SUM(mao.quantity)                     AS quantity       -- SAFETY: removed ::public.word64type; keep as numeric
    FROM utxos u
    JOIN public.ma_tx_out mao
      ON mao.tx_out_id = u.id
    GROUP BY u.address, mao.ident
  ),

  /* 4) Pack token balances per address into an array, and keep a cheap token_count. */
  token_arrays AS (
    SELECT
      ts.address,
      ARRAY_AGG(ROW(ts.address, ts.ident, ts.quantity)::"cardano_graphql"."AssetBalance") AS token_balances,
      COUNT(*) AS token_count  -- SAFETY: removed ::int; keep bigint
    FROM token_sums ts
    GROUP BY ts.address
  )

  /* 5) Build summary per address with a single projection:
        - "assetBalances" = [ ADA_row ] || token_balances
        - "utxosCount" = computed once
        - "assetCount" = 1 (ADA) + token_count (0 if none) */
  SELECT
    ROW(
      ia.address,
      ROW(
        /* ADA row (always present) concatenated with token array if any; no ORDER BY needed */
        /* ident as -1 is ADA sentinel key */
        COALESCE(
          ARRAY[ROW(ia.address, -1::bigint, a.ada_quantity)::"cardano_graphql"."AssetBalance"]
            || COALESCE(ta.token_balances, ARRAY[]::"cardano_graphql"."AssetBalance"[]),
          ARRAY[ROW(ia.address, -1::bigint, a.ada_quantity)::"cardano_graphql"."AssetBalance"]
        ),
        COALESCE(a.utxos_count, 0::bigint),         -- SAFETY: ensure bigint literal
        /* 1 (ADA) + number of token rows */
        1::bigint + COALESCE(ta.token_count, 0::bigint)  -- SAFETY: keep arithmetic in bigint
      )::"cardano_graphql"."PaymentAddressSummary"
    )::"cardano_graphql"."PaymentAddress"
  FROM input_addresses ia
  LEFT JOIN ada_and_counts a ON a.address = ia.address
  LEFT JOIN token_arrays   ta ON ta.address = ia.address
  ORDER BY ia.address;
$func$;


