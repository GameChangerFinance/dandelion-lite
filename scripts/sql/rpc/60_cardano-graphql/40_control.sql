-- Refresh asset token registry cache from github, to avoid stale deletes
DELETE FROM cardano_graphql.control_table
WHERE key = 'asset_registry_commit';

-- drop index idx_ma_tx_mint_cache_assetId;
-- Optional: Index to speed up joins by assetId
-- CREATE INDEX IF NOT EXISTS idx_ma_tx_mint_cache_assetId
-- ON cardano_graphql.ma_tx_mint_cache (assetId);

-- Optional: FK-style index for joins on ident
CREATE INDEX IF NOT EXISTS idx_ma_tx_mint_cache_ident
  ON cardano_graphql.ma_tx_mint_cache (ident);

  --drop function cardano_graphql.update_ma_tx_mint_cache CASCADE;
CREATE OR REPLACE FUNCTION cardano_graphql_ctl.update_ma_tx_mint_cache()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- INSERT new or UPDATE existing entry
  INSERT INTO cardano_graphql.ma_tx_mint_cache (ident, asset_id,
      first_mint_tx_hash, first_mint_slot_no, first_mint_block_no,
      last_mint_tx_hash, last_mint_slot_no, last_mint_block_no)
  SELECT
      ma.id,
      (ma.policy || ma.name)::bytea,

      first_tx.hash,
      first_block.slot_no,
      first_block.block_no,

      last_tx.hash,
      last_block.slot_no,
      last_block.block_no
  FROM public.multi_asset ma
  JOIN LATERAL (
      SELECT tx.id, tx.hash, b.slot_no, b.block_no
      FROM public.ma_tx_mint mtm
      JOIN public.tx tx ON tx.id = mtm.tx_id
      JOIN public.block b ON b.id = tx.block_id
      WHERE mtm.ident = NEW.ident
      ORDER BY b.slot_no ASC, tx.id ASC
      LIMIT 1
  ) AS first_tx(first_id, hash, slot_no, block_no) ON true
  JOIN LATERAL (
      SELECT tx.id, tx.hash, b.slot_no, b.block_no
      FROM public.ma_tx_mint mtm
      JOIN public.tx tx ON tx.id = mtm.tx_id
      JOIN public.block b ON b.id = tx.block_id
      WHERE mtm.ident = NEW.ident
      ORDER BY b.slot_no DESC, tx.id DESC
      LIMIT 1
  ) AS last_tx(last_id, hash, slot_no, block_no) ON true
  JOIN public.block first_block ON first_block.slot_no = first_tx.slot_no
  JOIN public.block last_block ON last_block.slot_no = last_tx.slot_no
  WHERE ma.id = NEW.ident
  ON CONFLICT (ident) DO UPDATE SET
      last_mint_tx_hash  = EXCLUDED.last_mint_tx_hash,
      last_mint_slot_no  = EXCLUDED.last_mint_slot_no,
      last_mint_block_no = EXCLUDED.last_mint_block_no;

  RETURN NULL;
END;
$$;


  --DROP TRIGGER IF EXISTS trg_update_ma_tx_mint_cache ON public.ma_tx_mint ;

CREATE OR REPLACE TRIGGER trg_update_ma_tx_mint_cache
AFTER INSERT OR UPDATE ON public.ma_tx_mint
FOR EACH ROW
EXECUTE FUNCTION cardano_graphql_ctl.update_ma_tx_mint_cache();

  --drop function cardano_graphql_ctl.backfill_ma_tx_mint_cache cascade;

CREATE OR REPLACE FUNCTION cardano_graphql_ctl.backfill_ma_tx_mint_cache()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Drop trigger to avoid concurrency issues
  PERFORM 1 FROM pg_trigger
  WHERE tgname = 'trg_update_ma_tx_mint_cache';
  IF FOUND THEN
    DROP TRIGGER IF EXISTS trg_update_ma_tx_mint_cache ON public.ma_tx_mint;
  END IF;

  -- Run backfill safely
  INSERT INTO cardano_graphql.ma_tx_mint_cache (ident, asset_id,
      first_mint_tx_hash, first_mint_slot_no, first_mint_block_no,
      last_mint_tx_hash, last_mint_slot_no, last_mint_block_no)
  SELECT
      ma.id,
      (ma.policy || ma.name)::bytea,

      first_tx.hash,
      first_block.slot_no,
      first_block.block_no,

      last_tx.hash,
      last_block.slot_no,
      last_block.block_no
  FROM (
      SELECT DISTINCT ident FROM public.ma_tx_mint
  ) AS distinct_idents
  JOIN public.multi_asset ma ON ma.id = distinct_idents.ident
  JOIN LATERAL (
      SELECT tx.hash, b.slot_no, b.block_no
      FROM public.ma_tx_mint mtm
      JOIN public.tx tx ON tx.id = mtm.tx_id
      JOIN public.block b ON b.id = tx.block_id
      WHERE mtm.ident = ma.id
      ORDER BY b.slot_no ASC, tx.id ASC
      LIMIT 1
  ) AS first_tx(hash, slot_no, block_no) ON true
  JOIN LATERAL (
      SELECT tx.hash, b.slot_no, b.block_no
      FROM public.ma_tx_mint mtm
      JOIN public.tx tx ON tx.id = mtm.tx_id
      JOIN public.block b ON b.id = tx.block_id
      WHERE mtm.ident = ma.id
      ORDER BY b.slot_no DESC, tx.id DESC
      LIMIT 1
  ) AS last_tx(hash, slot_no, block_no) ON true
  JOIN public.block first_block ON first_block.slot_no = first_tx.slot_no
  JOIN public.block last_block ON last_block.slot_no = last_tx.slot_no
  ON CONFLICT (ident) DO UPDATE SET
      last_mint_tx_hash  = EXCLUDED.last_mint_tx_hash,
      last_mint_slot_no  = EXCLUDED.last_mint_slot_no,
      last_mint_block_no = EXCLUDED.last_mint_block_no;

  -- Re-create the trigger
  CREATE TRIGGER trg_update_ma_tx_mint_cache
  AFTER INSERT OR UPDATE ON public.ma_tx_mint
  FOR EACH ROW
  EXECUTE FUNCTION cardano_graphql_ctl.update_ma_tx_mint_cache();

END;
$$;


-- SELECT cardano_graphql_ctl.backfill_ma_tx_mint_cache();










