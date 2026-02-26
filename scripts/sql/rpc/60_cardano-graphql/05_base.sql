-- DROP SCHEMA IF EXISTS cardano_graphql CASCADE;

CREATE SCHEMA IF NOT EXISTS cardano_graphql ;
CREATE SCHEMA IF NOT EXISTS cardano_graphql_ctl ;

-- preventing failures in migration flows, attempt to keep up.sql verbatim
DROP VIEW IF EXISTS cardano_graphql."StakePool" CASCADE;
