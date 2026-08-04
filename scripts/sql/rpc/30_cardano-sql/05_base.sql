-- PRIVATE HELPER SCHEMA --

-- creates a private schema ment for helper functions for super-user only (current_user)
CREATE SCHEMA IF NOT EXISTS sql_private_extensions ;

-- PROTECTED PG_CURL EXTENSION --
-- CREATE EXTENSION IF NOT EXISTS pg_curl SCHEMA sql_private_extensions ; -- DEACTIVATED!

-- PROTECTED GET FUNCTION --
-- DROP FUNCTION IF EXISTS sql_private_extensions.get ;
-- CREATE OR REPLACE FUNCTION sql_private_extensions.get(url TEXT) RETURNS TEXT LANGUAGE SQL AS $BODY$ -- DEACTIVATED!
--     WITH s AS (SELECT
--         sql_private_extensions.curl_easy_reset(),
--         sql_private_extensions.curl_easy_setopt_url(url),
--         sql_private_extensions.curl_easy_perform(),
--         sql_private_extensions.curl_easy_getinfo_data_in()
--     ) SELECT convert_from(curl_easy_getinfo_data_in, 'utf-8') FROM s;
-- $BODY$;

-- DROP FUNCTION IF EXISTS sql_private_extensions.get_json ;
-- CREATE OR REPLACE FUNCTION sql_private_extensions.get_json(url TEXT) RETURNS JSON LANGUAGE SQL AS $BODY$ -- DEACTIVATED!
--     WITH s AS (SELECT
--         sql_private_extensions.curl_easy_reset(),
--         sql_private_extensions.curl_easy_setopt_url(url),
--         sql_private_extensions.curl_easy_perform(),
--         sql_private_extensions.curl_easy_getinfo_data_in()
--     ) SELECT CAST(convert_from(curl_easy_getinfo_data_in, 'utf-8') as JSON ) FROM s;
-- $BODY$;

-- PROTECTED POST FUNCTION --
-- DROP FUNCTION IF EXISTS sql_private_extensions.post ;
-- CREATE OR REPLACE FUNCTION sql_private_extensions.post(url TEXT, request JSON) RETURNS TEXT LANGUAGE SQL AS $BODY$  -- DEACTIVATED!
--     WITH s AS (SELECT
--         sql_private_extensions.curl_easy_reset(),
--         sql_private_extensions.curl_easy_setopt_postfields(convert_to(request::TEXT, 'utf-8')),
--         sql_private_extensions.curl_easy_setopt_url(url),
--         sql_private_extensions.curl_header_append('Content-Type', 'application/json; charset=utf-8'),
--         sql_private_extensions.curl_easy_perform(),
--         sql_private_extensions.curl_easy_getinfo_data_in()
--     ) SELECT convert_from(curl_easy_getinfo_data_in, 'utf-8') FROM s;
-- $BODY$;

-- DROP FUNCTION IF EXISTS sql_private_extensions.post_json ;
-- CREATE OR REPLACE FUNCTION sql_private_extensions.post_json(url TEXT, request JSON) RETURNS JSON LANGUAGE SQL AS $BODY$  -- DEACTIVATED!
--     WITH s AS (SELECT
--         sql_private_extensions.curl_easy_reset(),
--         sql_private_extensions.curl_easy_setopt_postfields(convert_to(request::TEXT, 'utf-8')),
--         sql_private_extensions.curl_easy_setopt_url(url),
--         sql_private_extensions.curl_header_append('Content-Type', 'application/json; charset=utf-8'),
--         sql_private_extensions.curl_easy_perform(),
--         sql_private_extensions.curl_easy_getinfo_data_in()
--     ) SELECT CAST(convert_from(curl_easy_getinfo_data_in, 'utf-8') as JSON ) FROM s;
-- $BODY$;

-- PROTECTED SCHEMA ALIASING FUNCTIONS --

-- creates a function that creates views in new_schema from all tables on original_schema
--DROP FUNCTION IF EXISTS sql_private_extensions.expose_all_tables ;
CREATE OR REPLACE FUNCTION sql_private_extensions.expose_all_tables(original_schema TEXT, new_schema TEXT) RETURNS VOID
LANGUAGE plpgsql
AS $BODY$
	DECLARE
	    tables CURSOR FOR
	        SELECT tablename
	        FROM pg_tables
	        WHERE 
		--tablename NOT LIKE 'pg_%' AND 
		schemaname = original_schema
	        ORDER BY tablename;
	BEGIN
	    FOR table_record IN tables LOOP
		EXECUTE format('CREATE OR REPLACE VIEW %s.%s AS SELECT * FROM %s.%s ;',
				new_schema,
				table_record.tablename,
				original_schema,
				table_record.tablename ) ; -- is important to use ; here!
	    END LOOP;
END $BODY$;



-- creates a function that creates views in new_schema from some whitelisted tables on original_schema
--DROP FUNCTION IF EXISTS sql_private_extensions.expose_some_tables ;
CREATE OR REPLACE FUNCTION sql_private_extensions.expose_some_tables(original_schema TEXT, new_schema TEXT, whitelisted_tables TEXT[]) RETURNS VOID
LANGUAGE plpgsql
AS $BODY$
        DECLARE
            tables CURSOR FOR
                SELECT tablename
                FROM pg_tables
                WHERE 
                --tablename NOT LIKE 'pg_%' AND 
                schemaname = original_schema
		AND
		tablename = ANY(whitelisted_tables)
                ORDER BY tablename;
        BEGIN
            FOR table_record IN tables LOOP
                EXECUTE format('CREATE OR REPLACE VIEW %s.%s AS SELECT * FROM %s.%s ;',
                                new_schema,
                                table_record.tablename,
                                original_schema,
                                table_record.tablename ) ; -- is important to use ; here!
            END LOOP;
END $BODY$;


-- creates a function that creates views in new_schema from all views on original_schema
--DROP FUNCTION IF EXISTS sql_private_extensions.expose_all_views ;
CREATE OR REPLACE FUNCTION sql_private_extensions.expose_all_views(original_schema TEXT, new_schema TEXT) RETURNS VOID
LANGUAGE plpgsql
AS $BODY$
        DECLARE
            views CURSOR FOR
                SELECT viewname
                FROM pg_views
                WHERE
                --viewname NOT LIKE 'pg_%' AND 
                schemaname = original_schema
                ORDER BY viewname;
        BEGIN
            FOR view_record IN views LOOP
                EXECUTE format('CREATE OR REPLACE VIEW %s.%s AS SELECT * FROM %s.%s ;',
                                new_schema,
                                view_record.viewname,
                                original_schema,
                                view_record.viewname ) ; -- is important to use ; here!
            END LOOP;
END $BODY$;



-- creates a function that creates views in new_schema from some whitelisted views on original_schema
--DROP FUNCTION IF EXISTS sql_private_extensions.expose_some_views ;
CREATE OR REPLACE FUNCTION sql_private_extensions.expose_some_views(original_schema TEXT, new_schema TEXT, whitelisted_views TEXT[]) RETURNS VOID
LANGUAGE plpgsql
AS $BODY$
        DECLARE
            views CURSOR FOR
                SELECT viewname
                FROM pg_views
                WHERE
                --viewname NOT LIKE 'pg_%' AND 
                schemaname = original_schema
		AND
		viewname = ANY(whitelisted_views)
                ORDER BY viewname;
        BEGIN
            FOR view_record IN views LOOP
                EXECUTE format('CREATE OR REPLACE VIEW %s.%s AS SELECT * FROM %s.%s ;',
                                new_schema,
                                view_record.viewname,
                                original_schema,
                                view_record.viewname ) ; -- is important to use ; here!
            END LOOP;
END $BODY$;


--DROP FUNCTION IF EXISTS sql_private_extensions.grant_read_only_access ;
CREATE OR REPLACE FUNCTION sql_private_extensions.grant_read_only_access(user_names TEXT, schema_name TEXT) RETURNS VOID
LANGUAGE plpgsql
AS $BODY$ BEGIN
	EXECUTE format('GRANT USAGE ON SCHEMA %s TO %s ;', schema_name, user_names ) ;
	EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %s TO %s;',schema_name, user_names ) ;
	EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %s GRANT SELECT ON TABLES TO %s ;',schema_name, user_names ) ;
	-- better do this manually: EXECUTE format('ALTER ROLE %s SET search_path TO %s;',user_names, schema_name ) ;
END $BODY$;

