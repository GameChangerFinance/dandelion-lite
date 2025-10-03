/* === Composite types ========================================= */

DROP TYPE IF EXISTS "cardano_graphql"."StakingAddress" CASCADE;
DROP TYPE IF EXISTS "cardano_graphql"."StakingAddressSummary" CASCADE;
DROP TYPE IF EXISTS "cardano_graphql"."StakingBalance" CASCADE; 

CREATE TYPE  "cardano_graphql"."StakingBalance" AS (
  "stakeAddress" character varying, -- bech32 stake1... like in public.stake_address.view
  "hash" public.addr29type, -- hex string like in public.stake_address.hash_raw, ex. e09b49d62267bbfbba884b839cef87e65887e3c675d22876cc66d4d730
  "scriptHash" public.hash28type, -- hex string like in public.stake_address.script_hash, 
  ident  bigint, -- getStakingAddresses() returns -1 as it's ident sentinel key for coin and staking is a coin-only system
  quantity numeric,            -- total sum of utxos value for this stake address (also same as sum of utxos value accross StakingAddressSummary.addresses). SAFETY: was public.word64type; aggregates can exceed 2^64-1
  rewards numeric,             -- total rewards sum for this stake address. SAFETY: was public.word64type; keep exact integer math without overflow
  withdrawals numeric,         -- total withdrawals sum for this stake address. SAFETY: was public.word64type
  "availableRewards" numeric   -- available rewards balance to withdraw for this stake address. SAFETY: was public.word64type; computed as sum/diff of large amounts
);

CREATE TYPE "cardano_graphql"."StakingAddressSummary" AS (
  "rewardBalance" "cardano_graphql"."StakingBalance", -- balance for this stake address
  "withdrawalsCount" bigint, --  number of withdrawals for this stake address. SAFETY: was integer; COUNT(*) returns bigint and can exceed int
  "utxosCount" bigint,       -- number of utxos for this stake address. SAFETY: was integer
  "addressCount" bigint,     -- count of items in StakingAddressSummary.addresses. SAFETY: was integer
  "addresses" varchar [] -- list of addresses having this stake credential, in other words list of addresses in computed utxos
);

CREATE TYPE "cardano_graphql"."StakingAddress" AS (
  "stakeAddress" character varying,  --bech32 stake1... like in public.stake_address.view
  "hash" public.addr29type, -- hex string like in public.stake_address.hash_raw, ex. e09b49d62267bbfbba884b839cef87e65887e3c675d22876cc66d4d730
  "scriptHash" public.hash28type,  -- hex string like in public.stake_address.script_hash, 
  summary "cardano_graphql"."StakingAddressSummary"
);


/* === Optimized function ================================================ */
CREATE OR REPLACE FUNCTION "cardano_graphql"."getStakingAddresses"(
  "stakeAddresses" varchar[],
  "atBlock"   public.word31type DEFAULT NULL
)
RETURNS SETOF "cardano_graphql"."StakingAddress"
LANGUAGE sql
STABLE
AS $func$
/**************************************************************************************************
 * getStakingAddresses
 *
 * Inputs:
 *   - "stakeAddresses": array of bech32 stake addresses (stake1...) matching public.stake_address.view
 *   - "atBlock": optional block number (inclusive). If NULL, use the latest ledger state (no historical filtering).
 *
 * Behavior:
 *   - Preserves input order and duplicates using UNNEST ... WITH ORDINALITY.
 *   - Skips inputs that do not resolve to a known stake_address (keeps reference behavior; avoids NULLs in NOT NULL fields).
 *   - All values are lovelace-only (coin), ident is always -1.
 *   - Historical snapshot rules (when "atBlock" is not NULL):
 *       * UTXOs: outputs created at block_no ≤ atBlock and not consumed at or before atBlock
 *       * Withdrawals: sums/counts for withdrawals with block_no ≤ atBlock
 *       * Rewards (public.reward): sum where spendable_epoch ≤ epoch_at(atBlock)
 *       * Reserves/Treasury/Proposal Refund (public.reward_rest): sum where spendable_epoch ≤ epoch_at(atBlock)
 *
 * Output row shape (one row per input that resolves to a stake_address):
 *   "StakingAddress" (
 *     stakeAddress public.addr29type,     -- returned as bech32 (cast), see note below
 *     hash varchar,                       -- hex of stake_address.hash_raw
 *     summary "StakingAddressSummary" (
 *       rewardBalances "StakingBalance"[],  -- single element array
 *       withdrawalsCount integer,
 *       utxosCount integer
 *     )
 *   )
 *
 **************************************************************************************************/
WITH
-- 1) Normalize inputs, preserve order & duplicates, and resolve to stake_address rows
input_sa AS (
  SELECT
    sa_in.addr              AS bech32_view,
    sa_in.ord               AS ord,
    sa.id                   AS addr_id,
    sa.hash_raw             AS hash_raw,
    sa.view                 AS view,
    sa.script_hash          AS script_hash
  FROM UNNEST("stakeAddresses") WITH ORDINALITY AS sa_in(addr, ord)
  LEFT JOIN public.stake_address sa
    ON sa.view = sa_in.addr
),

-- 2) Determine snapshot epoch for "atBlock" (NULL means "tip"/latest)
snapshot AS (
  SELECT
    "atBlock" AS at_block,
    CASE
      WHEN "atBlock" IS NULL THEN NULL::bigint
      ELSE (
        SELECT b.epoch_no
        FROM public.block b
        WHERE b.block_no <= "atBlock"
        ORDER BY b.block_no DESC
        LIMIT 1
      )
    END AS snapshot_epoch
),

/* 3) UTXOs at snapshot
   - If "atBlock" IS NULL: include only unspent (consumed_by_tx_id IS NULL)
   - Else: include tx_out created at block_no ≤ atBlock and either unconsumed OR consumed after atBlock
*/
utxo_agg AS (
  SELECT
    i.addr_id,
    COALESCE(SUM(txo.value), 0) AS utxo_sum,   -- SAFETY: removed ::public.word64type; SUM(bigint)→numeric
    COALESCE(COUNT(*), 0)       AS utxo_count  -- SAFETY: removed ::integer; keep native bigint
  FROM input_sa i
  JOIN public.tx_out txo
    ON txo.stake_address_id = i.addr_id
  LEFT JOIN public.tx tx_create
    ON tx_create.id = txo.tx_id
  LEFT JOIN public.block b_create
    ON b_create.id = tx_create.block_id
  LEFT JOIN public.tx tx_consume
    ON tx_consume.id = txo.consumed_by_tx_id
  LEFT JOIN public.block b_consume
    ON b_consume.id = tx_consume.block_id
  CROSS JOIN snapshot s
  WHERE i.addr_id IS NOT NULL
    AND (
      (
        s.at_block IS NULL
        AND txo.consumed_by_tx_id IS NULL              -- tip: only unspent
      )
      OR
      (
        s.at_block IS NOT NULL
        AND b_create.block_no <= s.at_block            -- created on/before snapshot
        AND (txo.consumed_by_tx_id IS NULL
             OR b_consume.block_no > s.at_block)       -- not consumed by snapshot
      )
    )
  GROUP BY i.addr_id
),

/* 3b) Addresses from the computed UTXOs (same snapshot logic as above) */
utxo_addr_agg AS (
  SELECT
    i.addr_id,
    array_remove(array_agg(DISTINCT txo.address), NULL) AS addresses,
    COALESCE(COUNT(DISTINCT txo.address), 0) AS address_count -- SAFETY: removed ::integer; keep bigint
  FROM input_sa i
  JOIN public.tx_out txo
    ON txo.stake_address_id = i.addr_id
  LEFT JOIN public.tx tx_create
    ON tx_create.id = txo.tx_id
  LEFT JOIN public.block b_create
    ON b_create.id = tx_create.block_id
  LEFT JOIN public.tx tx_consume
    ON tx_consume.id = txo.consumed_by_tx_id
  LEFT JOIN public.block b_consume
    ON b_consume.id = tx_consume.block_id
  CROSS JOIN snapshot s
  WHERE i.addr_id IS NOT NULL
    AND (
      (
        s.at_block IS NULL
        AND txo.consumed_by_tx_id IS NULL
      )
      OR
      (
        s.at_block IS NOT NULL
        AND b_create.block_no <= s.at_block
        AND (txo.consumed_by_tx_id IS NULL
             OR b_consume.block_no > s.at_block)
      )
    )
  GROUP BY i.addr_id
),

/* 4) Withdrawals up to snapshot */
withdrawals_agg AS (
  SELECT
    i.addr_id,
    COALESCE(SUM(w.amount), 0) AS withdrawals_sum, -- SAFETY: removed ::public.word64type
    COALESCE(COUNT(*), 0)      AS withdrawals_count -- SAFETY: removed ::integer
  FROM input_sa i
  JOIN public.withdrawal w
    ON w.addr_id = i.addr_id
  JOIN public.tx wtx
    ON wtx.id = w.tx_id
  JOIN public.block wb
    ON wb.id = wtx.block_id
  CROSS JOIN snapshot s
  WHERE i.addr_id IS NOT NULL
    AND (s.at_block IS NULL OR wb.block_no <= s.at_block)
  GROUP BY i.addr_id
),

/* 5) Rewards (spendable) up to snapshot epoch */
rewards_agg AS (
  SELECT
    i.addr_id,
    COALESCE(SUM(r.amount), 0) AS rewards_sum -- SAFETY: removed ::public.word64type
  FROM input_sa i
  JOIN public.reward r
    ON r.addr_id = i.addr_id
  CROSS JOIN snapshot s
  WHERE i.addr_id IS NOT NULL
    AND (s.snapshot_epoch IS NULL OR r.spendable_epoch <= s.snapshot_epoch)
  GROUP BY i.addr_id
),

/* 6) reward_rest components (reserves / treasury / proposal_refund) up to snapshot epoch */
reserves_agg AS (
  SELECT
    i.addr_id,
    COALESCE(SUM(rr.amount), 0) AS reserves_sum -- SAFETY: removed ::public.word64type
  FROM input_sa i
  JOIN public.reward_rest rr
    ON rr.addr_id = i.addr_id
   AND rr.type = 'reserves'
  CROSS JOIN snapshot s
  WHERE i.addr_id IS NOT NULL
    AND (s.snapshot_epoch IS NULL OR rr.spendable_epoch <= s.snapshot_epoch)
  GROUP BY i.addr_id
),
treasury_agg AS (
  SELECT
    i.addr_id,
    COALESCE(SUM(rr.amount), 0) AS treasury_sum -- SAFETY: removed ::public.word64type
  FROM input_sa i
  JOIN public.reward_rest rr
    ON rr.addr_id = i.addr_id
   AND rr.type = 'treasury'
  CROSS JOIN snapshot s
  WHERE i.addr_id IS NOT NULL
    AND (s.snapshot_epoch IS NULL OR rr.spendable_epoch <= s.snapshot_epoch)
  GROUP BY i.addr_id
),
proposal_refund_agg AS (
  SELECT
    i.addr_id,
    COALESCE(SUM(rr.amount), 0) AS proposal_refund_sum -- SAFETY: removed ::public.word64type
  FROM input_sa i
  JOIN public.reward_rest rr
    ON rr.addr_id = i.addr_id
   AND rr.type = 'proposal_refund'
  CROSS JOIN snapshot s
  WHERE i.addr_id IS NOT NULL
    AND (s.snapshot_epoch IS NULL OR rr.spendable_epoch <= s.snapshot_epoch)
  GROUP BY i.addr_id
),

/* 7) Merge aggregates into a single row per resolved stake address (ordered later by input ord) */
agg AS (
  SELECT
    i.ord,
    i.bech32_view,
    i.addr_id,
    i.hash_raw,
    i.view,
    i.script_hash,
    COALESCE(u.utxo_sum, 0)                           AS utxo_sum,            -- SAFETY: keep as numeric
    COALESCE(u.utxo_count, 0::bigint)                 AS utxo_count,          -- SAFETY: ensure bigint
    COALESCE(w.withdrawals_sum, 0)                    AS withdrawals_sum,     -- SAFETY: numeric
    COALESCE(w.withdrawals_count, 0::bigint)          AS withdrawals_count,   -- SAFETY: bigint
    COALESCE(re.rewards_sum, 0)                       AS rewards_sum,         -- SAFETY: numeric
    COALESCE(rv.reserves_sum, 0)                      AS reserves_sum,        -- SAFETY: numeric
    COALESCE(tr.treasury_sum, 0)                      AS treasury_sum,        -- SAFETY: numeric
    COALESCE(pr.proposal_refund_sum, 0)               AS proposal_refund_sum, -- SAFETY: numeric
    COALESCE(ua.addresses, ARRAY[]::varchar[])        AS addresses,
    COALESCE(ua.address_count, 0::bigint)             AS address_count        -- SAFETY: bigint
  FROM input_sa i
  LEFT JOIN utxo_agg             u  ON u.addr_id  = i.addr_id
  LEFT JOIN utxo_addr_agg        ua ON ua.addr_id = i.addr_id
  LEFT JOIN withdrawals_agg      w  ON w.addr_id  = i.addr_id
  LEFT JOIN rewards_agg          re ON re.addr_id = i.addr_id
  LEFT JOIN reserves_agg         rv ON rv.addr_id = i.addr_id
  LEFT JOIN treasury_agg         tr ON tr.addr_id = i.addr_id
  LEFT JOIN proposal_refund_agg  pr ON pr.addr_id = i.addr_id
  WHERE i.addr_id IS NOT NULL
)

/* 8) Build the composite output:
      - "StakingAddress" with:
          stakeAddress :: public.addr29type  (bech32 'view', cast as needed)
          hash         :: varchar            (hex of hash_raw)
          summary      :: "StakingAddressSummary" with:
            rewardBalances :: array of one "StakingBalance"
            withdrawalsCount, utxosCount
*/
SELECT
  ROW(
    a.view,                 -- StakingAddress.stakeAddress (varchar)
    a.hash_raw,             -- StakingAddress.hash (addr29type)
    a.script_hash,          -- StakingAddress.scriptHash (hash28type)
-- StakingAddress.summary
    ROW(
      ROW(                                -- (single) rewardBalance
        a.view,                           -- StakingBalance.stakeAddress (varchar)
        a.hash_raw,                       -- StakingBalance.hash (addr29type)
        a.script_hash,                    -- StakingBalance.scriptHash (hash28type)
        -1::bigint,                       -- ident
        a.utxo_sum,                       -- quantity (numeric)
        a.rewards_sum,                    -- rewards (numeric)
        a.withdrawals_sum,                -- withdrawals (numeric)
        (a.rewards_sum
           + a.reserves_sum
           + a.treasury_sum
           + a.proposal_refund_sum
           - a.withdrawals_sum
        )                                 -- SAFETY: removed ::public.word64type; keep arithmetic in numeric
      )::"cardano_graphql"."StakingBalance",
      a.withdrawals_count,                -- withdrawalsCount (bigint)
      a.utxo_count,                       -- utxosCount (bigint)
      a.address_count,                    -- addressCount (bigint)
      a.addresses                         -- addresses
    )::"cardano_graphql"."StakingAddressSummary"
  )::"cardano_graphql"."StakingAddress"
FROM agg a
ORDER BY a.ord;  -- preserve original input order (and duplicates)
$func$;



-- Example: 
-- SELECT *
-- FROM "cardano_graphql"."getStakingAddresses"(
--   ARRAY[
--     'stake_test1up97ct2wt8jqlly2cnkhuwc7tvevmjpp7h6ts3rucpksy8c8cnspn',
--     'stake_test1uzd5n43zv7alhw5gfwpeemu8uevg0c7xwhfzsakvvm2dwvqe08pn0'
--   ],
--   123467
-- );