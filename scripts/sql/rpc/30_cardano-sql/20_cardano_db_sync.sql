-- This cardano_db_sync schema will became an 'alias' of public schema as Cardano DB Sync is currently unable to use other than public schema for indexing the chain
CREATE SCHEMA IF NOT EXISTS cardano_db_sync ;

-- Lets expose some tables and views from public into cardano_db_sync
--SELECT sql_private_extensions.expose_all_tables('public','cardano_db_sync') ;
--SELECT sql_private_extensions.expose_all_views('public','cardano_db_sync') ;
SELECT sql_private_extensions.expose_some_tables('public','cardano_db_sync',ARRAY[
'ada_pots',
'anchor_offline_data',
'anchor_offline_fetch_error',
'block',
'collateral_tx_in',
'collateral_tx_out',
'committee_de_registration',
'committee_registration',
'constitution',
'cost_model',
'datum',
'delegation',
'delegation_vote',
'delisted_pool',
'drep_distr',
'drep_hash',
'drep_registration',
'epoch',
'epoch_param',
'epoch_stake',
'epoch_stake_progress',
'epoch_sync_time',
'extra_key_witness',
'extra_migrations',
'gov_action_proposal',
'ma_tx_mint',
'ma_tx_out',
'meta',
'multi_asset',
'new_committee',
'off_chain_pool_data',
'off_chain_pool_fetch_error',
'off_chain_vote_data',
'off_chain_vote_fetch_error',
'param_proposal',
'pool_hash',
'pool_metadata_ref',
'pool_owner',
'pool_relay',
'pool_retire',
'pool_update',
'pot_transfer',
'redeemer',
'redeemer_data',
'reference_tx_in',
'reserve',
'reserved_pool_ticker',
'reverse_index',
'reward',
'schema_version',
'script',
'slot_leader',
'stake_address',
'stake_deregistration',
'stake_registration',
'treasury',
'treasury_withdrawal',
'tx',
'tx_in',
-- 'tx_metadata', CHANG-UPDATE: commented out as cardano-db-sync 13.4.0.1 breaks on boot sequence because of this
'tx_out',
'voting_anchor',
'voting_procedure',
'withdrawal'
]) ;

SELECT sql_private_extensions.expose_some_views('public','cardano_db_sync',ARRAY[
'utxo_byron_view',
'utxo_view'
]) ;

-- Lets apply SELECT only permissions to these users for cardano_db_sync
SELECT sql_private_extensions.grant_read_only_access('web_anon, authenticator', 'cardano_db_sync');

