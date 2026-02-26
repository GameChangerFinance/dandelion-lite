INSERT INTO cardano_graphql.control_table (key, last_value)
VALUES ('sql_migration_version', '1')
ON CONFLICT (key) DO UPDATE
  SET last_value = EXCLUDED.last_value;