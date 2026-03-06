-- from up.sql

CREATE INDEX IF NOT EXISTS idx_block_hash
    ON public.block(hash);

CREATE INDEX IF NOT EXISTS idx_multi_asset_name
    ON public.multi_asset(name);

CREATE INDEX IF NOT EXISTS idx_multi_asset_policy
    ON public.multi_asset(policy);

CREATE INDEX IF NOT EXISTS idx_reward_type
    ON public.reward(type);

CREATE INDEX IF NOT EXISTS idx_tx_hash
    ON public.tx(hash);

CREATE INDEX IF NOT EXISTS idx_tx_in_consuming_tx
   ON public.tx_in(tx_out_id);


-------------------------------------------------------------------------
-- CUSTOM
-------------------------------------------------------------------------

-- If you JOIN or filter using policy + name
CREATE UNIQUE INDEX IF NOT EXISTS idx_asset_registry_cache_asset_policy_asset_name ON cardano_graphql.asset_registry_cache (asset_policy, asset_name);

-- -- If you often query/filter by fingerprint
-- CREATE UNIQUE INDEX IF NOT EXISTS idx_asset_registry_fingerprint
-- ON cardano_graphql.asset_registry_cache (fingerprint);

-- For fast lookup by assetId
CREATE UNIQUE INDEX IF NOT EXISTS idx_asset_registry_cache_asset_id
ON cardano_graphql.asset_registry_cache (
  (asset_policy || asset_name)
);




-- On ma_tx_out: index on (tx_out_id, ident) to speed up join + grouping
CREATE INDEX IF NOT EXISTS  idx_ma_tx_out_tx_out_id_ident ON public.ma_tx_out(tx_out_id, ident);

-- On multi_asset: index on (policy, name) to speed up join and assetId computation
CREATE INDEX IF NOT EXISTS  idx_multi_asset_policy_name ON public.multi_asset(policy, name);

-- Optional: index on id if used elsewhere as a foreign key
CREATE INDEX IF NOT EXISTS  idx_multi_asset_id ON public.multi_asset(id);

-- On asset_registry_cache: index on (asset_policy, asset_name)
CREATE INDEX IF NOT EXISTS  idx_arc_policy_name ON cardano_graphql.asset_registry_cache(asset_policy, asset_name);




-- For the JOIN: speeds up ma_tx_mint.ident = multi_asset.id
CREATE INDEX IF NOT EXISTS idx_ma_tx_mint_ident ON ma_tx_mint(ident);

-- On multi_asset: speeds up the JOIN and assetId calculation
CREATE INDEX IF NOT EXISTS  idx_multi_asset_id ON multi_asset(id);

-- Optional: if querying by policyId
CREATE INDEX IF NOT EXISTS  idx_multi_asset_policy ON multi_asset(policy);

-- Optional: if querying by name (used in assetId computation)
CREATE INDEX IF NOT EXISTS  idx_multi_asset_name ON multi_asset(name);

-- Optional: if querying or filtering by tx_id
CREATE INDEX IF NOT EXISTS  idx_ma_tx_mint_tx_id ON ma_tx_mint(tx_id);





-- Indexes to speed up encoding-based joins
CREATE INDEX IF NOT EXISTS idx_multi_asset_policy_hex
ON public.multi_asset ((encode(policy::bytea, 'hex')));

CREATE INDEX IF NOT EXISTS idx_multi_asset_name_hex
ON public.multi_asset ((encode(name::bytea, 'hex')));

-- Most relevant one, used on relations and common assetId based lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_multi_asset_assetid_bytea
ON public.multi_asset ((policy::bytea || name::bytea));

-- -- (Used in blockfrost, not here) Index on hex encoded combined assetId (policy || name)
-- CREATE UNIQUE INDEX IF NOT EXISTS idx_multi_asset_assetId
-- ON public.multi_asset ((encode(policy::bytea || name::bytea, 'hex')));

CREATE UNIQUE INDEX IF NOT EXISTS idx_multi_asset_fingerprint
ON public.multi_asset (fingerprint);


-------------------------------------------------------------------------
-- For Grafast plans produced by paymentAddresses:
--------------------------------------------------------------------------
-- Removed as producing errors on mainnet: 
--    ERROR:  index row requires 10520 bytes, maximum size is 8191
DROP INDEX IF EXISTS tx_out_address_idx;
-- -- Filter by address quickly (used by WHERE ab.address = ...)
-- -- Pick ONE: simple or composite. Composite can also help downstream join patterns.
-- CREATE INDEX IF NOT EXISTS tx_out_address_idx
--   ON public.tx_out(address);
-- -- Or:
-- -- CREATE INDEX CONCURRENTLY IF NOT EXISTS tx_out_address_id_idx
-- --   ON public.tx_out(address, id);

-- Anti-join for "unspent": speeds WHERE NOT EXISTS/LEFT JOIN IS NULL
CREATE INDEX IF NOT EXISTS tx_in_out_ref_idx
  ON public.tx_in (tx_out_id, tx_out_index);

-- Native tokens branch: join u.id -> ma_tx_out.tx_out_id
CREATE INDEX IF NOT EXISTS ma_tx_out_tx_out_id_idx
  ON public.ma_tx_out (tx_out_id);

-- If you often group by ident after filtering by address:
CREATE INDEX IF NOT EXISTS ma_tx_out_tx_out_id_ident_idx
  ON public.ma_tx_out (tx_out_id, ident);

-- Asset lookup by ident -> multi_asset.id (should already be PK; add if missing)
CREATE UNIQUE INDEX IF NOT EXISTS multi_asset_id_uq
  ON public.multi_asset (id);

-- Asset registry join
CREATE INDEX IF NOT EXISTS asset_registry_cache_policy_name_idx
  ON cardano_graphql.asset_registry_cache (asset_policy, asset_name);

-- Removed as producing errors on mainnet: 
--    ERROR:  index row requires 10520 bytes, maximum size is 8191
DROP INDEX IF EXISTS tx_out_address_txid_index_idx;
-- -- Keep your simple address index (it’s in use).
-- -- Add a composite one to enable ordered reads for GROUP BY:
-- CREATE INDEX IF NOT EXISTS tx_out_address_txid_index_idx
--   ON public.tx_out (address, tx_id, index);


-------------------------------------------------------------------------
-- For common input/output lookups to improve relations on transactions :
--------------------------------------------------------------------------

-- light & generic, helps many address-lookup queries
CREATE INDEX IF NOT EXISTS idx_tx_in_txoutid_index
ON public.tx_in (tx_out_id, tx_out_index);

-- symmetry (only if you query these often):
CREATE INDEX IF NOT EXISTS idx_ref_in_txoutid_index
ON public.reference_tx_in (tx_out_id, tx_out_index);

CREATE INDEX IF NOT EXISTS idx_col_in_txoutid_index
ON public.collateral_tx_in (tx_out_id, tx_out_index);



-- 1) Index for address-based lookups in tx_out
-- WARNING: disabled because was failing on mainnet due to table sizes!
-- CREATE INDEX IF NOT EXISTS idx_tx_out_address
-- ON public.tx_out (address);

-- 2) Index for address-based lookups in collateral_tx_out
CREATE INDEX IF NOT EXISTS idx_collateral_tx_out_address
ON public.collateral_tx_out (address);

-- 3) Index to quickly filter tx by hash
CREATE INDEX IF NOT EXISTS idx_tx_hash
ON public.tx (hash);
