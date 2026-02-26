

CREATE TABLE IF NOT EXISTS cardano_graphql.asset_registry_cache (
  asset_policy text NOT NULL,
  asset_name text NOT NULL,
  name text NOT NULL,
  description text NOT NULL,
  ticker text,
  url text,
  logo text,
  decimals integer
);



-- replaced by PaymentAddresses return type, could be handy to bring this one back
-- DROP VIEW IF EXISTS cardano_graphql."AssetBalance";
          -- -- SIMPLER, ALLOWS GRAFAST TO NEST ASSET RELATION (IF WANTED) TO OPTIMIZE REPETITIONS WITH N+1 GRAFAST FEATURES
          -- -- Aims to be like AssetBalance in cardano graphql
          -- CREATE OR REPLACE VIEW cardano_graphql."AssetBalance" AS
          -- -- ADA (Lovelace) (no referenced asset metadata)
          -- SELECT
          --   u.address,
          --   -1::bigint AS "ident", -- fake foreign key to nest Asset relationship (-1 is ADA sentinel key)
          --   SUM(u.value) AS "quantity"
          -- FROM cardano_graphql."Utxo" u
          -- GROUP BY u.address

          -- UNION ALL

          -- -- Native Token balances (with referenced asset metadata)
          -- SELECT
          --   u.address,
          --   mao.ident::bigint AS "ident", -- fake foreign key to nest Asset relationship
          --   SUM(mao.quantity) AS "quantity"
          -- FROM cardano_graphql."Utxo" u
          -- JOIN public.ma_tx_out mao ON mao.tx_out_id = u.id
          -- GROUP BY u.address, mao.ident;


CREATE OR REPLACE VIEW cardano_graphql."CoinBalance" AS
-- ADA (Lovelace) (no referenced asset metadata)
SELECT
  u.address,
  -1::bigint AS "ident", -- fake foreign key to nest Asset relationship (-1 is ADA sentinel key)
  SUM(u.value) AS "quantity"
FROM cardano_graphql."Utxo" u
GROUP BY u.address;


CREATE OR REPLACE VIEW cardano_graphql."NativeTokenBalance" AS
-- Native Token balances (with referenced asset metadata)
SELECT
  u.address,
  mao.ident::bigint AS "ident", -- fake foreign key to nest Asset relationship
  SUM(mao.quantity) AS "quantity"
FROM cardano_graphql."Utxo" u
JOIN public.ma_tx_out mao ON mao.tx_out_id = u.id
GROUP BY u.address, mao.ident;







/* --------------NETWORK SPECIFIC COIN SETUP----------------
To simplify the SQL setup, following coin info function will
deliver network agnostic values.

TODO: add via Postgraphile plugin network specific overrides  
------------------------------------------------------------ */

-- A single constant row for ADA, with types matching the Asset view.

CREATE OR REPLACE FUNCTION cardano_graphql.coin_registry_cache()
RETURNS TABLE (
  "ma_id"       bigint,
  "policyId"    public.hash28type,
  "assetName"   public.asset32type,
  "fingerprint" varchar,
  "assetId"     bytea,
  decimals      integer,
  description   text,
  logo          text,
  name          text,
  ticker        text,
  url           text,
  "isCoin"      boolean
)
LANGUAGE sql
stable
AS $func$
  SELECT
    /* ADA has no entry in public.multi_asset, so -1 this is a sentinel key, that helps us lookup for these special rows */
    -1::bigint                                                    AS "ma_id",

    /* Client side systems should decide how to normalize these values for coin, for example forcing them to became 'ada'*/
    /* Problem is there is no way to safely represent the hexadecimal value 'ada' and hash28type, asset32type and bytea are dealt as hexadecimal bytes*/
    NULL::public.hash28type                                       AS "policyId",
    NULL::public.asset32type                                      AS "assetName",

    /* No fingerprint for ADA */
    NULL::varchar                                                 AS "fingerprint",

    /* idem: hexadecimal bytea 'ada' value is invalid and this is confusing decode('ada','hex')::bytea*/
    NULL::bytea                                                   AS "assetId",

    /* Your requested constants */
    6                                                             AS decimals,
    'the official coin of the network'                            AS description,
    NULL::text                                                    AS logo,
    'coin'                                                        AS name, 
    NULL::text                                                    AS ticker,
    NULL::text                                                    AS url,
    
    /* Boolean flag added for extreme clarity: this is the coin of this network */
    TRUE                                                          AS "isCoin";

  /* -------- STRICT LITERAL VERSION (NOT RECOMMENDED) ----------
     Casting '\xada' into bytea/domains will typically fail due to 
     odd hex length.
     Example (will not pass in most setups):
       E'\\xada'::bytea
       E'\\xada'::public.hash28type
       E'\\xada'::public.asset32type
     ------------------------------------------------------------ */
$func$;





-- used for relations where only token asset info is needed without coin, so we save the cost of the useless union per millions of rows.
CREATE OR REPLACE VIEW cardano_graphql."TokenAsset" AS
SELECT
  ma.id AS "ma_id", -- used by fake foreign keys to nest this view by *.ident column
  ma.policy AS "policyId",
  ma.name AS "assetName",
  ma.fingerprint AS "fingerprint",
  --encode(ma.policy::bytea || ma.name::bytea, 'hex')::bytea AS "assetId",
  (ma.policy || ma.name )::bytea AS "assetId",
  arc.decimals,
  arc.description,
  arc.logo,
  arc.name,
  arc.ticker,
  arc.url,
  FALSE AS "isCoin"        -- new: quickly identify non-coin rows
    -- NULL::integer AS "firstAppearedInSlot",
    -- NULL::character(40) AS "metadataHash",
FROM public.multi_asset ma
LEFT JOIN cardano_graphql.asset_registry_cache arc
  ON arc.asset_policy = encode(ma.policy::bytea, 'hex')
 AND arc.asset_name  = encode(ma.name::bytea, 'hex');

-- used for balance relations where only coins are needed.
CREATE OR REPLACE VIEW cardano_graphql."CoinAsset" AS
-- Inject a synthetic ADA row so "ident IS NULL" can resolve to a real object 
SELECT * FROM cardano_graphql."coin_registry_cache"();

-- used for balance relations where coin + token asset information is needed.
CREATE OR REPLACE VIEW cardano_graphql."Asset" AS
-- SELECT * FROM cardano_graphql."coin_registry_cache"()
SELECT * FROM cardano_graphql."CoinAsset"
UNION ALL
SELECT * FROM cardano_graphql."TokenAsset";



-- WARNING: Seems official StakePool view (or when posgraphile relations are in place) does not guarantee a single row per pool hash / pool id. (For ex. search for the ANGEL ticker, it throws 3 results, apparently several reg certs per tx)
--          Also there are new needs such as the status field
--          So as incremental setup, lets drop the former view and replace it for a patched version to keep up.sql verbatim as shipped by official maintainers

DROP VIEW IF EXISTS cardano_graphql."StakePool" CASCADE;

CREATE OR REPLACE VIEW cardano_graphql."StakePool" AS
WITH
  -- Latest pool_update per pool (one row per hash_id, using max(id))
  latest_pool_update AS (
    SELECT pu.*
    FROM pool_update pu
    JOIN (
      SELECT hash_id, max(id) AS id
      FROM pool_update
      GROUP BY hash_id
    ) latest
      ON latest.hash_id = pu.hash_id
     AND latest.id = pu.id
  ),

  -- Last retirement epoch (if any) per pool
  pool_last_retire AS (
    SELECT
      hash_id,
      max(retiring_epoch) AS retiring_epoch
    FROM pool_retire
    GROUP BY hash_id
  ),

  -- Current epoch (tip)
  current_epoch AS (
    SELECT max(epoch_no) AS epoch_no
    FROM block
  )

SELECT
  pool.fixed_cost        AS "fixedCost",
  pool_hash.hash_raw     AS "hash",
  pool_hash.view         AS "id",
  pool.hash_id           AS "hash_id",
  pool.id                AS "update_id",
  pool.margin            AS "margin",
  pool_metadata_ref.hash AS "metadataHash",
  block.block_no         AS "blockNo",
  pool.registered_tx_id  AS "updated_in_tx_id",
  pool.pledge            AS "pledge",
  stake_address.view     AS "rewardAddress",
  pool_metadata_ref.url  AS "url",
  pool.deposit           AS deposit,
  CASE
    WHEN r.retiring_epoch IS NULL THEN 'registered'
    WHEN r.retiring_epoch > ce.epoch_no THEN 'retiring'
    ELSE 'retired'
  END AS "status"
FROM latest_pool_update AS pool
  LEFT JOIN pool_metadata_ref
    ON pool.meta_id = pool_metadata_ref.id
  INNER JOIN tx
    ON pool.registered_tx_id = tx.id
  INNER JOIN block
    ON tx.block_id = block.id
  INNER JOIN stake_address
    ON pool.reward_addr_id = stake_address.id
  INNER JOIN pool_hash
    ON pool_hash.id = pool.hash_id
  CROSS JOIN current_epoch ce
  LEFT JOIN pool_last_retire r
    ON r.hash_id = pool.hash_id;


-- When StakePool->StakePoolMetadata relation is stablished, or when StakePoolMetadata is queried individually, if we dont de-duplicate per pool_id we get multiple results

CREATE OR REPLACE VIEW cardano_graphql."StakePoolMetadata" AS
SELECT DISTINCT ON (pm.pool_id)
  pm.ticker_name AS "ticker",
  pm.hash        AS "metadataHash",
  pm.json        AS "value",         -- jsonb metadata
  pm.bytes       AS "bytes",

  -- internal/wiring fields
  pm.pool_id     AS "pool_id",    -- FK -> pool_hash.id
  pm.pmr_id      AS "pmr_id",     -- FK -> pool_metadata_ref.id
  pm.id          AS "id"          -- PK of off_chain_pool_data
FROM public.off_chain_pool_data pm
ORDER BY
  pm.pool_id,
  pm.id DESC;  -- take latest off-chain row for each pool_id



DROP TYPE IF EXISTS "cardano_graphql"."TransactionHistory_order_by" CASCADE;
-- Cardano GraphQL: transaction history sort order enum
-- Values are case-sensitive and exposed to PostGraphile as-is.
CREATE TYPE cardano_graphql."TransactionHistory_order_by" AS ENUM (
  'ASC',      -- chronological (oldest first)
  'DESC',     -- chronological (newest first) - default
  'NATURAL'   -- "natural" order by tx.id (surrogate PK insertion order)
);


CREATE OR REPLACE FUNCTION cardano_graphql."getTransactionHistoryForAddresses"(
  addresses character varying[],                          -- required, base type matches public.tx_out.address
  "sort" cardano_graphql."TransactionHistory_order_by" DEFAULT 'DESC',  -- optional: 'ASC' | 'DESC' | 'NATURAL'
  extended boolean DEFAULT false                          -- optional: when true, include reference/collateral relations
)
RETURNS SETOF cardano_graphql."Transaction"
LANGUAGE sql
STABLE
AS $func$
  WITH RECURSIVE
  -- Normalize and deduplicate the address list once.
  -- This is the only "recursive" CTE label; query itself is not truly recursive.
  addr AS (
    SELECT DISTINCT unnest(addresses)::varchar AS address
  ),

  -- 1) Direct outputs (tx_out): transactions that *produce* outputs to these addresses.
  tx_ids_from_outputs AS (
    SELECT DISTINCT o.tx_id
    FROM addr
    JOIN public.tx_out AS o
      ON o.address = addr.address
  ),

  -- 2) Inputs that spend those outputs (tx_in): transactions that *consume* UTxOs at these addresses.
  tx_ids_from_inputs AS (
    SELECT DISTINCT i.tx_in_id AS tx_id
    FROM addr
    JOIN public.tx_out AS o
      ON o.address = addr.address
    JOIN public.tx_in AS i
      ON i.tx_out_id    = o.tx_id
     AND i.tx_out_index = o.index
  ),

  -- 3) Reference inputs (reference_tx_in): transactions that *reference* UTxOs at these addresses.
  tx_ids_from_reference_inputs AS (
    SELECT DISTINCT ri.tx_in_id AS tx_id
    FROM addr
    JOIN public.tx_out AS o
      ON o.address = addr.address
    JOIN public.reference_tx_in AS ri
      ON ri.tx_out_id    = o.tx_id
     AND ri.tx_out_index = o.index
  ),

  -- 4) Collateral inputs (collateral_tx_in): transactions that *use as collateral* UTxOs at these addresses.
  tx_ids_from_collateral_inputs AS (
    SELECT DISTINCT ci.tx_in_id AS tx_id
    FROM addr
    JOIN public.tx_out AS o
      ON o.address = addr.address
    JOIN public.collateral_tx_in AS ci
      ON ci.tx_out_id    = o.tx_id
     AND ci.tx_out_index = o.index
  ),

  -- 5) Collateral outputs (collateral_tx_out): transactions whose collateral outputs pay to these addresses.
  tx_ids_from_collateral_outputs AS (
    SELECT DISTINCT co.tx_id
    FROM addr
    JOIN public.collateral_tx_out AS co
      ON co.address = addr.address
  ),

  -- Union of all tx_ids (deduped once).
  --
  -- NOTE on `extended`:
  -- - When extended = FALSE, only outputs + inputs are included (history in the "usual" sense).
  -- - When extended = TRUE, reference/collateral relations are also included.
  --
  -- In pure SQL CTE form, the extra CTEs are still planned; if you need to *physically*
  -- skip them when extended = FALSE, you can convert this function to PL/pgSQL and
  -- branch on `extended` with two RETURN QUERY blocks.
  all_tx_ids AS (
    SELECT tx_id
    FROM tx_ids_from_outputs

    UNION

    SELECT tx_id
    FROM tx_ids_from_inputs

    UNION

    -- extended relations are gated: if extended = FALSE these yield zero rows
    SELECT tx_id
    FROM tx_ids_from_reference_inputs
    WHERE extended

    UNION

    SELECT tx_id
    FROM tx_ids_from_collateral_inputs
    WHERE extended

    UNION

    SELECT tx_id
    FROM tx_ids_from_collateral_outputs
    WHERE extended
  )

  -- Final result: rows from your existing Transaction view.
  -- We keep the core join verbatim and only add ORDER BY logic.
  SELECT
    t.*
  FROM
    cardano_graphql."Transaction" AS t
    JOIN all_tx_ids AS a
      ON a.tx_id = t."id"
  ORDER BY
    -- When "sort" = 'ASC': chronological (oldest first) by includedAt.
    CASE WHEN "sort" = 'ASC' THEN t."includedAt" END ASC,

    -- When "sort" = 'DESC': chronological (newest first) by includedAt.
    -- This is the default and recommended for "history".
    CASE WHEN "sort" = 'DESC' THEN t."includedAt" END DESC,

    -- When "sort" = 'NATURAL': "natural" order by tx surrogate PK.
    -- tx.id is monotonic in db-sync, so this approximates insertion/chain order
    -- and is very index-friendly (idx_tx_pkey).
    CASE WHEN "sort" = 'NATURAL' THEN t."id" END DESC;
$func$;
