

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



CREATE OR REPLACE VIEW cardano_graphql."StakePoolMetadata" AS
SELECT DISTINCT ON (ph.id)
  ph.id                                       AS id,
  ph.view                                     AS pool_id,
  pmr.url                                     AS url,
  pmr.hash                                    AS hash,
  ocpd.json                                   AS json,
  pu.registered_tx_id                         AS updated_in_tx_id,
  pu.id                                       AS pool_update_id
FROM public.pool_hash AS ph
JOIN public.pool_update AS pu
  ON pu.hash_id = ph.id
JOIN public.pool_metadata_ref AS pmr
  ON pmr.id = pu.meta_id
LEFT JOIN public.off_chain_pool_data AS ocpd
  ON ocpd.pmr_id = pmr.id
ORDER BY
  ph.id,
  pu.registered_tx_id DESC; 
-- to pick the last last pool_update.registered_tx_id means metadata from last update per pool_hash.id

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



-- -- Could be extended with more fields to support new kind of assets
-- -- For example asset_registry_cache for registered native tokens and another to detect NFTs or DiskNfts
-- CREATE OR REPLACE VIEW cardano_graphql."Asset" AS
-- -- Inject a synthetic ADA row so "ident IS NULL" can resolve to a real object 
-- SELECT * FROM cardano_graphql."coin_registry_cache"()
-- UNION ALL
-- SELECT
--   ma.id AS "ma_id", -- used by fake foreign keys to nest this view by *.ident column
--   ma.policy AS "policyId",
--   ma.name AS "assetName",
--   ma.fingerprint AS "fingerprint",
--   --encode(ma.policy::bytea || ma.name::bytea, 'hex')::bytea AS "assetId",
--   (ma.policy || ma.name )::bytea AS "assetId",
--   arc.decimals,
--   arc.description,
--   arc.logo,
--   arc.name,
--   arc.ticker,
--   arc.url,
--   FALSE AS "isCoin"        -- new: quickly identify non-coin rows
--     -- NULL::integer AS "firstAppearedInSlot",
--     -- NULL::character(40) AS "metadataHash",
-- FROM public.multi_asset ma
-- LEFT JOIN cardano_graphql.asset_registry_cache arc
--   ON arc.asset_policy = encode(ma.policy::bytea, 'hex')
--  AND arc.asset_name  = encode(ma.name::bytea, 'hex');


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


-- used for balance relations where coin + token asset information is needed.
CREATE OR REPLACE VIEW cardano_graphql."Asset" AS
-- Inject a synthetic ADA row so "ident IS NULL" can resolve to a real object 
SELECT * FROM cardano_graphql."coin_registry_cache"()
UNION ALL
SELECT * FROM cardano_graphql."TokenAsset";

-- TODO: remove this line soon!
DROP VIEW IF EXISTS cardano_graphql."TransactionMetadata";
-- CREATE OR REPLACE VIEW cardano_graphql."TransactionMetadata" AS
-- SELECT 
--     id ,
--     key,
--     json ,
--     bytes,
--     tx_id
-- FROM public."tx_metadata" meta;


CREATE TABLE IF NOT EXISTS cardano_graphql.control_table (
  key text PRIMARY KEY,
  last_value text NOT NULL,
  artifacts text
);


CREATE TABLE IF NOT EXISTS cardano_graphql.ma_tx_mint_cache (
    ident bigint PRIMARY KEY, -- FK to multi_asset.id
    asset_id bytea NOT NULL UNIQUE, -- (policy || name)::bytea

    first_mint_tx_hash public.hash32type NOT NULL,
    first_mint_slot_no public.word63type NOT NULL,
    first_mint_block_no public.word31type NOT NULL,

    last_mint_tx_hash public.hash32type NOT NULL,
    last_mint_slot_no public.word63type NOT NULL,
    last_mint_block_no public.word31type NOT NULL
);

