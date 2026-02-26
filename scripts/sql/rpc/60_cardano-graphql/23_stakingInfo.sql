/* ============================================================================
 * getStakingInfo(): Koios-derived account_info() normalized to this API return shape
 *
 * - Minimal edits to ease future Koios rebases
 * - Output fields/types match "cardano_graphql"."StakingInfo"
 * - Numeric fields are returned as numeric directly (no ::text)
 * - Original output lines are kept as comments for diff-friendly maintenance
 * - Original dependencies that need to be supported:
 *      grest.cip5_hex_to_stake_addr
 *      grest.cip129_hex_to_drep_id
 *      grest.is_dangling_delegation (* removed - use nested GQL relations instead, read comments)
 *      cardano.bech32_decode_data
 *      cardano.bech32_encode
 * ========================================================================== */

/* === Enum + Composite types ============================================ */

DROP TYPE IF EXISTS "cardano_graphql"."StakingInfoStatus" CASCADE;
DROP TYPE IF EXISTS "cardano_graphql"."StakingInfo" CASCADE;

CREATE TYPE "cardano_graphql"."StakingInfoStatus" AS ENUM (
  'REGISTERED',
  'NOT_REGISTERED'
);

CREATE TYPE "cardano_graphql"."StakingInfo" AS (
  "stakeAddress"     character varying, -- bech32 stake1...
  "hash"             public.addr29type,  -- hex of stake_address.hash_raw (29 bytes => 58 hex chars)
  "scriptHash"       public.hash28type,  -- hex of stake_address.script_hash (28 bytes => 56 hex chars), NULL if key credential

  "status"           "cardano_graphql"."StakingInfoStatus",

  "delegatedPoolId"  character varying, -- Koios delegated_pool (pool1...)
  "delegatedDRepId"  character varying, -- delegated DRep credential id (CIP-129 format; see cip129_hex_to_drep_id)
  "delegatedDRepView" character varying, -- drep_hash.view (non-CIP-129 form; use this for smart-tag relation to public.drep_hash.view)

  "totalBalance"     numeric,           -- total balance in lovelace (computed; numeric-safe)
  "deposit"          numeric,           -- deposit in lovelace (numeric-safe)
  "reserves"         numeric,           -- reserves in lovelace (numeric-safe)
  "treasury"         numeric,           -- treasury in lovelace (numeric-safe)
  "proposalRefund"   numeric,           -- proposal refund in lovelace (numeric-safe)

  "availableRewards" numeric            -- available rewards in lovelace (numeric-safe; equivalent to Koios rewards_available)
);


/* === Dependencies ============================================ */

-- 20_koios-artifacts_1.3.2/000_utilities/cip5.sql

-- CIP References
-- 0005: Common bech32 prefixes https://cips.cardano.org/cip/CIP-0005
-- 0019: Cardano Addresses https://cips.cardano.org/cip/CIP-0019

CREATE OR REPLACE FUNCTION "cardano_graphql".cip5_hex_to_stake_addr(_raw bytea)
RETURNS text
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  IF _raw IS NULL THEN
   RETURN NULL;
  ELSE
    RETURN cardano.tools_shelley_address_build(
      ''::bytea,
      FALSE,
      SUBSTRING(_raw FROM 2),
      FALSE,
      SUBSTRING(ENCODE(_raw, 'hex') from 2 for 1)::integer
      )::text;
  END IF;
END;
$$;

-- 20_koios-artifacts_1.3.2/000_utilities/cip129.sql

CREATE OR REPLACE FUNCTION "cardano_graphql".cip129_hex_to_drep_id(_raw bytea, _is_script boolean)
RETURNS text
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  IF _raw IS NULL THEN RETURN NULL; END IF;
  IF _is_script THEN
    RETURN cardano.bech32_encode('drep', ('\x23'::bytea || _raw));
  ELSE
    RETURN cardano.bech32_encode('drep', ('\x22'::bytea || _raw));
  END IF;
END;
$$;
COMMENT ON FUNCTION "cardano_graphql".cip129_hex_to_drep_id IS 'Returns DRep Credential ID in CIP-129 format from raw binary hex'; -- noqa: LT01


-- 20_koios-artifacts_1.3.2/000_utilities/is_dangling_delegation.sql

-- CREATE OR REPLACE FUNCTION "cardano_graphql".is_dangling_delegation(delegation_id bigint)
-- RETURNS boolean
-- LANGUAGE plpgsql
-- AS $$
-- DECLARE
--   curr_epoch bigint;
--   num_retirements bigint;

-- BEGIN

--   SELECT INTO curr_epoch MAX(no) FROM epoch;
--   -- revised logic:
--   -- check for any pool retirement record exists for the pool corresponding to given delegation
--   -- pool retiring epoch is current or in the past (future scheduled retirements don't count)
--   -- pool retiring epoch is after delegation cert submission epoch
--   -- and there does not exist a pool_update transaction for this pool that came after currently analyzed pool retirement tx
--   -- and before last transaction of the epoch preceeding the pool retirement epoch.. pool update submitted after that point in
--   -- time is too late and pool should have been fully retired
--   SELECT INTO num_retirements COUNT(*)
--   FROM delegation AS d
--     INNER JOIN pool_retire AS pr ON d.id = delegation_id
--       AND pr.hash_id = d.pool_hash_id
--       AND pr.retiring_epoch <= curr_epoch
--       AND pr.retiring_epoch > (SELECT b.epoch_no FROM block AS b INNER JOIN tx AS t on t.id = d.tx_id and t.block_id = b.id)
--       AND NOT EXISTS
--         ( SELECT 1
--           FROM pool_update AS pu
--           WHERE pu.hash_id = d.pool_hash_id
--             AND pu.registered_tx_id >= pr.announced_tx_id
--             AND pu.registered_tx_id <= (
--               SELECT i_last_tx_id
--               FROM "cardano_graphql".epoch_info_cache AS eic
--               WHERE eic.epoch_no = pr.retiring_epoch - 1
--             )
--         );

--   RETURN num_retirements > 0;
-- END;
-- $$;

-- COMMENT ON FUNCTION "cardano_graphql".is_dangling_delegation IS 'Returns a boolean to indicate whether a given delegation id corresponds to a delegation that has been made dangling by retirement of a stake pool associated with it'; --noqa: LT01


/* === Function ============================================ */


-- Original Koios signature (kept for reference):
-- CREATE OR REPLACE FUNCTION grest.account_info(_stake_addresses text [])

CREATE OR REPLACE FUNCTION "cardano_graphql"."getStakingInfo"("stakeAddresses" text [])
RETURNS SETOF "cardano_graphql"."StakingInfo"
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  sa_id_list integer[] DEFAULT NULL;
BEGIN
  /*
   * Maintain Koios behavior: decode stake1... into credential bytes and match
   * stake_address.hash_raw. This keeps compatibility with upstream updates.
   */

  -- Original:
  -- SELECT INTO sa_id_list
  --   array_agg(id)
  -- FROM stake_address
  -- WHERE stake_address.hash_raw = ANY(
  --   SELECT cardano.bech32_decode_data(n)
  --   FROM UNNEST(_stake_addresses) AS n
  -- );

  SELECT INTO sa_id_list
    array_agg(id)
  FROM public.stake_address
  WHERE public.stake_address.hash_raw = ANY(
    SELECT cardano.bech32_decode_data(n)
    FROM UNNEST("stakeAddresses") AS n
  );

  RETURN QUERY

    SELECT
      /* ------------------------------------------------------------------
       * Original output projection (commented out line-by-line)
       * ------------------------------------------------------------------ */

      -- grest.cip5_hex_to_stake_addr(status_t.hash_raw)::varchar AS stake_address,
      -- CASE WHEN status_t.registered = TRUE THEN
      --   'registered'
      -- ELSE
      --   'not registered'
      -- END AS status,
      -- pool_t.delegated_pool,
      -- vote_t.delegated_drep,
      -- (COALESCE(utxo_t.utxo, 0)
      --  + COALESCE(rewards_t.rewards, 0)
      --  + COALESCE(reserves_t.reserves, 0)
      --  + COALESCE(treasury_t.treasury, 0)
      --  - COALESCE(withdrawals_t.withdrawals, 0))::text AS total_balance,
      -- COALESCE(utxo_t.utxo, 0)::text AS utxo,
      -- COALESCE(rewards_t.rewards, 0)::text AS rewards,
      -- COALESCE(withdrawals_t.withdrawals, 0)::text AS withdrawals,
      -- (COALESCE(rewards_t.rewards, 0)
      --  + COALESCE(reserves_t.reserves, 0)
      --  + COALESCE(treasury_t.treasury, 0)
      --  + COALESCE(proposal_refund_t.proposal_refund, 0)
      --  - COALESCE(withdrawals_t.withdrawals, 0))::text AS rewards_available,
      -- COALESCE(status_t.deposit,0)::text AS deposit,
      -- COALESCE(reserves_t.reserves, 0)::text AS reserves,
      -- COALESCE(treasury_t.treasury, 0)::text AS treasury,
      -- COALESCE(proposal_refund_t.proposal_refund, 0)::text AS proposal_refund

      /* ------------------------------------------------------------------
       * Normalized output projection (matches "cardano_graphql"."StakingInfo")
       *
       * Type safety / overflow notes:
       * - We DO NOT render numerics to text. All amounts remain numeric.
       * - SUM(bigint) in PostgreSQL yields numeric, which is overflow-safe.
       * - We only cast to numeric where the underlying type may be int8/domain.
       * ------------------------------------------------------------------ */

      "cardano_graphql".cip5_hex_to_stake_addr(status_t.hash_raw)::varchar AS "stakeAddress",

      status_t.hash_raw     AS "hash",
      status_t.script_hash  AS "scriptHash",

      CASE
        WHEN status_t.registered = TRUE THEN 'REGISTERED'::"cardano_graphql"."StakingInfoStatus"
        ELSE 'NOT_REGISTERED'::"cardano_graphql"."StakingInfoStatus"
      END AS "status",

      pool_t.delegated_pool::varchar AS "delegatedPoolId",
      vote_t.delegated_drep::varchar AS "delegatedDRepId",
      vote_t.delegated_drep_view::varchar AS "delegatedDRepView",

      (
        COALESCE(utxo_t.utxo, 0)
        + COALESCE(rewards_t.rewards, 0)
        + COALESCE(reserves_t.reserves, 0)
        + COALESCE(treasury_t.treasury, 0)
        - COALESCE(withdrawals_t.withdrawals, 0)
      )::numeric AS "totalBalance",

      COALESCE(status_t.deposit, 0)::numeric AS "deposit",
      COALESCE(reserves_t.reserves, 0)::numeric AS "reserves",
      COALESCE(treasury_t.treasury, 0)::numeric AS "treasury",
      COALESCE(proposal_refund_t.proposal_refund, 0)::numeric AS "proposalRefund",

      (
        COALESCE(rewards_t.rewards, 0)
        + COALESCE(reserves_t.reserves, 0)
        + COALESCE(treasury_t.treasury, 0)
        + COALESCE(proposal_refund_t.proposal_refund, 0)
        - COALESCE(withdrawals_t.withdrawals, 0)
      )::numeric AS "availableRewards"

    FROM
      (
        SELECT
          sa.id,
          sa.hash_raw,

          /* Added (minimal): expose script_hash for "scriptHash" output */
          sa.script_hash,

          EXISTS (
            SELECT TRUE FROM stake_registration AS sr
            WHERE sr.addr_id = sa.id
              AND NOT EXISTS (
                SELECT TRUE
                FROM stake_deregistration AS sd
                WHERE
                  sd.addr_id = sr.addr_id
                  AND sd.tx_id > sr.tx_id
                LIMIT 1
              )
          ) AS registered,
          (
            SELECT sr.deposit FROM stake_registration AS sr
            WHERE sr.addr_id = sa.id
              AND NOT EXISTS (
                SELECT TRUE
                FROM stake_deregistration AS sd
                WHERE
                  sd.addr_id = sr.addr_id
                  AND sd.tx_id > sr.tx_id
                LIMIT 1
              )
          ) AS deposit
        FROM public.stake_address sa
        WHERE sa.id = ANY(sa_id_list)
      ) AS status_t
    LEFT JOIN (
        SELECT
          dv.addr_id,
          COALESCE("cardano_graphql".cip129_hex_to_drep_id(dh.raw, dh.has_script), dh.view::text) AS delegated_drep,
          dh.view::text AS delegated_drep_view
        FROM delegation_vote AS dv
          INNER JOIN drep_hash AS dh ON dh.id = dv.drep_hash_id
        WHERE dv.addr_id = ANY(sa_id_list)
          AND NOT EXISTS (
            SELECT TRUE
            FROM delegation_vote AS dv1
            WHERE dv1.addr_id = dv.addr_id
              AND dv1.id > dv.id
            LIMIT 1)
          AND NOT EXISTS (
            SELECT TRUE
            FROM stake_deregistration
            WHERE stake_deregistration.addr_id = dv.addr_id
              AND stake_deregistration.tx_id > dv.tx_id
            LIMIT 1)
          AND NOT EXISTS (
            SELECT TRUE
            FROM drep_registration
            WHERE drep_registration.drep_hash_id = dv.drep_hash_id
              AND drep_registration.tx_id > dv.tx_id
              AND drep_registration.deposit < 0
            LIMIT 1)
      ) AS vote_t ON vote_t.addr_id = status_t.id
    LEFT JOIN (
        SELECT
          delegation.addr_id,
          cardano.bech32_encode('pool', ph.hash_raw)::varchar AS delegated_pool
        FROM delegation
          INNER JOIN pool_hash AS ph ON ph.id = delegation.pool_hash_id
        WHERE delegation.addr_id = ANY(sa_id_list)
          AND NOT EXISTS (
            SELECT TRUE
            FROM delegation AS delegation1
            WHERE delegation1.addr_id = delegation.addr_id
              AND delegation1.id > delegation.id
            LIMIT 1)
          AND NOT EXISTS (
            SELECT TRUE
            FROM stake_deregistration
            WHERE stake_deregistration.addr_id = delegation.addr_id
              AND stake_deregistration.tx_id > delegation.tx_id
            LIMIT 1)
        -- * Koios filter (removed): hides "dangling delegations" to pools that have effectively retired.
        -- This depends on grest.is_dangling_delegation() which in turn depends on grest.epoch_info_cache
        -- and external cron maintenance. We remove it to keep this function self-contained.
        -- Impact:
        --   delegated_pool now reflects the latest delegation certificate target even if the pool is retired.
        --   End users may see delegatedPoolId but earn no rewards until they re-delegate.
            -- skip delegations that were followed by at least one pool retirement
            -- AND NOT grest.is_dangling_delegation(delegation.id)
      ) AS pool_t ON pool_t.addr_id = status_t.id
    LEFT JOIN (
        SELECT
          tx_out.stake_address_id,
          COALESCE(SUM(value), 0) AS utxo
        FROM tx_out
        WHERE tx_out.stake_address_id = ANY(sa_id_list)
          AND tx_out.consumed_by_tx_id IS NULL
        GROUP BY tx_out.stake_address_id
      ) AS utxo_t ON utxo_t.stake_address_id = status_t.id
    LEFT JOIN (
        SELECT
          reward.addr_id,
          COALESCE(SUM(amount), 0) AS rewards
        FROM reward
        WHERE reward.addr_id = ANY(sa_id_list)
          -- db-sync’s reward rows have a spendable_epoch, meaning rewards can exist in the DB that are not yet spendable/withdrawable (i.e., not yet actually in the reward account balance). The db-sync schema docs describe spendable_epoch as “the epoch in which the reward is distributed and can be spent.”
          AND reward.spendable_epoch <= (
            SELECT MAX(no)
            FROM epoch
          )
        GROUP BY reward.addr_id
      ) AS rewards_t ON rewards_t.addr_id = status_t.id
    LEFT JOIN (
        SELECT
          wdrl.addr_id,
          COALESCE(SUM(amount), 0) AS withdrawals
        FROM withdrawal AS wdrl
        WHERE wdrl.addr_id = ANY(sa_id_list)
        GROUP BY wdrl.addr_id
      ) AS withdrawals_t ON withdrawals_t.addr_id = status_t.id
    LEFT JOIN (
        SELECT
          rr.addr_id,
          COALESCE(SUM(amount), 0) AS reserves
        FROM reward_rest AS rr
        WHERE rr.addr_id = ANY(sa_id_list)
          AND rr.type = 'reserves'
          AND rr.spendable_epoch <= (
            SELECT MAX(no)
            FROM epoch
          )
        GROUP BY rr.addr_id
      ) AS reserves_t ON reserves_t.addr_id = status_t.id
    LEFT JOIN (
        SELECT
          tr.addr_id,
          COALESCE(SUM(amount), 0) AS treasury
        FROM reward_rest AS tr
        WHERE tr.addr_id = ANY(sa_id_list)
          AND tr.type = 'treasury'
          AND tr.spendable_epoch <= (
            SELECT MAX(no)
            FROM epoch
          )
        GROUP BY tr.addr_id
      ) AS treasury_t ON treasury_t.addr_id = status_t.id
    LEFT JOIN (
        SELECT
          pr.addr_id,
          COALESCE(SUM(amount), 0) AS proposal_refund
        FROM reward_rest AS pr
        WHERE pr.addr_id = ANY(sa_id_list)
          AND pr.type = 'proposal_refund'
          AND pr.spendable_epoch <= (
            SELECT MAX(no)
            FROM epoch
          )
        GROUP BY
          pr.addr_id
      ) AS proposal_refund_t ON proposal_refund_t.addr_id = status_t.id
    ;

END;
$$;

COMMENT ON FUNCTION "cardano_graphql"."getStakingInfo"(text[])
IS 'Koios-derived account_info normalized to cardano_graphql.getStakingInfo (numeric-safe, no text roundtrips).';
