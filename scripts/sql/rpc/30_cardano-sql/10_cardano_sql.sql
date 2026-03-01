-- CARDANO SQL SCHEMA --
CREATE SCHEMA IF NOT EXISTS cardano_sql;

-- FUNCTION TO RUN SQL QUERY WITH INJECTION PREVENTION --
CREATE OR REPLACE FUNCTION cardano_sql.query(query TEXT, params JSON) RETURNS SETOF json AS $$
    BEGIN
	    EXECUTE format('prepare query_%s (json) AS WITH tmp as (%s) select row_to_json(tmp.*) from tmp',MD5(query), query);
            RETURN QUERY EXECUTE format('execute query_%s(%L)', MD5(query),params);
            --DEALLOCATE query;
	    EXECUTE format('DEALLOCATE query_%s',MD5(query));
    EXCEPTION 
	WHEN invalid_sql_statement_name OR duplicate_prepared_statement THEN
	    EXECUTE format('DEALLOCATE query_%s',MD5(query));
	    EXECUTE format('prepare query_%s (json) AS WITH tmp as (%s) select row_to_json(tmp.*) from tmp',MD5(query), query);
	    RETURN QUERY EXECUTE format('execute query_%s(%L)', MD5(query),params);
	    --DEALLOCATE query;
	    EXECUTE format('DEALLOCATE query_%s',MD5(query));
    END
    $$ LANGUAGE plpgsql;

-- EXAMPLE USAGE -- 
-- curl 'http://127.0.0.1:8050/rpc/query'  -H 'Content-Profile: cardano_sql'   -H 'Content-Type: application/json' --data-raw $'{"query":"SELECT * FROM cardano_db_sync.tx_out ORDER BY value DESC NULLS LAST LIMIT CAST($1->>\'limit\' AS BIGINT)","params":{"limit":"3"}}'


-- TODO: implement manifest using string templates to simplify setup and avoid requiring cardano-sql-companion
-- manifest (requires scripts/lib/install-postgres.sh string templates)--
-- DROP FUNCTION IF EXISTS cardano_sql.manifest ;
-- CREATE OR REPLACE FUNCTION cardano_sql.manifest() RETURNS JSON LANGUAGE SQL AS $BODY$
-- 	SELECT json_object(
--		'dltTag':{{DLT}},
--		'networkTag':{{NETWORK}},
--		'name':{{NODE_NAME}},
--		'groups':{{NODE_GROUPS}},
--		'extensions':string_to_array({{NODE_EXTENSIONS}}, ','),
--		'extension':json_object(
--			'cardano-node':json_object(),
--			'cardano-db-sync':json_object(),
--			'ogmios':json_object()
--		)
--	)
--$BODY$
--    SECURITY DEFINER
--    -- Set a search_path with priorities to allow plugin schema users to use sql_private_extensions schema underneath this function
--    SET search_path = sql_private_extensions, cardano_sql;

-- Example usage --
-- SELECT cardano_sql.manifest() ;
-- curl 'http://127.0.0.1:8050/rpc/query'  -H 'Content-Profile: cardano_sql'   -H 'Content-Type: application/json' --data-raw $'{"query":"SELECT cardano_sql.manifest()","params":{}}'



--manifest (using cardano-sql-companion REST API)--
-- DROP FUNCTION IF EXISTS cardano_sql.manifest ;
-- CREATE OR REPLACE FUNCTION cardano_sql.manifest() RETURNS JSON LANGUAGE SQL AS $BODY$  -- DEACTIVATED!
--      WITH s AS (
--          SELECT sql_private_extensions.get_json('http://cardano-sql-companion:4000/info/manifest')
--      ) SELECT * FROM s;
--  $BODY$
--      SECURITY DEFINER
--      -- Set a search_path with priorities to allow plugin schema users to use sql_private_extensions schema underneath this function
--      SET search_path = sql_private_extensions, cardano_sql;

-- Example usage --
-- SELECT cardano_sql.manifest() ;
-- curl 'http://127.0.0.1:8050/rpc/query'  -H 'Content-Profile: cardano_sql'   -H 'Content-Type: application/json' --data-raw $'{"query":"SELECT cardano_sql.manifest()","params":{}}'








-- USERS
-- Lets apply SELECT only permissions to these users for sql
SELECT sql_private_extensions.grant_read_only_access('web_anon, authenticator', 'cardano_sql');

