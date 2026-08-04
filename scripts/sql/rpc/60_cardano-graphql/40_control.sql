CREATE TABLE IF NOT EXISTS cardano_graphql.control_table (
  key text PRIMARY KEY,
  last_value text NOT NULL,
  artifacts text
);


-- Refresh asset token registry cache from github, to avoid stale deletes
DELETE FROM cardano_graphql.control_table
WHERE key = 'asset_registry_commit';
