-- PLUGIN SCHEMA --
CREATE SCHEMA IF NOT EXISTS ogmios;

-- PUBLIC PLUGIN FUNCTIONS --

-- -- submitTx --
-- DROP FUNCTION IF EXISTS ogmios.submit_tx ;
-- CREATE OR REPLACE FUNCTION ogmios.submit_tx(params JSON) RETURNS JSON LANGUAGE SQL AS $BODY$ -- DEACTIVATED!
-- 	WITH s AS (
--         SELECT sql_private_extensions.post_json(
-- 			'http://ogmios:1337/',
-- 			FORMAT(
-- 				'{"params": {"transaction": {"cbor": "%s"} },"method": "submitTransaction","jsonrpc": "2.0","id":"submitTransaction-%s"}',
-- 				params->>'txHex',
-- 				MD5(params->>'txHex')
-- 			)::json
-- 		)
--     ) SELECT * FROM s;
-- $BODY$
--     SECURITY DEFINER
--     -- Set a search_path with priorities to allow plugin schema users to use sql_private_extensions schema underneath this function
--     SET search_path = sql_private_extensions, ogmios;

-- Example usage --
-- SELECT * from ogmios.submit_tx('{"txHex":"84a70081825820bd47ba3d4219191c81c06c995e32852b0973e16f7fe7686145af3ae4df6a3a1702018282583900d8ad931196680f24c99f65244aa099277684ea1c09f9c95fd9c9d72ef3eb9839fb3be3e66b330bc9d3213d498c3d61a1fe4b33699f04dce5821a00124864a1581ca408727858c111fdf1e36c684b37c29b8ba7f4b49b41ab2da44013f4a14e47616d654368616e6765724e46540182583900d8ad931196680f24c99f65244aa099277684ea1c09f9c95fd9c9d72ef3eb9839fb3be3e66b330bc9d3213d498c3d61a1fe4b33699f04dce51b00000002f2938043021a00031b29031a027ae97f075820e41592f6e3c06e0d96aa5d61d578d24bfcb3fdbbc5772fdc056e39c9edde46fc09a1581ca408727858c111fdf1e36c684b37c29b8ba7f4b49b41ab2da44013f4a14e47616d654368616e6765724e4654010f00a20081825820b495c77a7e6695ee6ad44c330f590ca20e9d740a185a93f1128c4e578a58270558401345f7745a62a6e4872cd375f1e8aee4f3620f223d09f0422189020f4fc93f1d660abcc80f9f14767f207881b2dfe5a600b92fbc412f210db72fd4a018a32f0f01818201828200581cd8ad931196680f24c99f65244aa099277684ea1c09f9c95fd9c9d72e82051a027ae97ff5a21849a56362696478403837356239333830383636653964353665373131306230656533313039363263313664396434616531303366383239643632626466666432636265376336316468726566657272657260657469746c65704e4654204d696e74696e672044656d6f6474797065627478617663312e301902d1a178386134303837323738353863313131666466316533366336383462333763323962386261376634623439623431616232646134343031336634a16e47616d654368616e6765724e4654a866617574686f727247616d654368616e6765722057616c6c65746b6465736372697074696f6e774f6e6c792031204e4654732077657265206d696e7465646566696c657381a469617277656176654964782b6a6e356435355662566470764133793957416c7a52524250317a686b71386c33516955522d765648622d30696d656469615479706569696d6167652f706e6766736861323536784035623865653239363430626632343037346133393838626236623835323136353733316665383631323739336566356137343433336631363839653263623462637372637835697066733a2f2f516d56574778414b704232537879335a6e665a7364743367786f634645555565384750426372614c545a53514b5465696d6167657835697066733a2f2f516d56574778414b704232537879335a6e665a7364743367786f634645555565384750426372614c545a53514b54696d656469615479706569696d6167652f706e67646e616d656e47616d654368616e6765724e46546375726c781b68747470733a2f2f67616d656368616e6765722e66696e616e63656776657273696f6e63312e30"}'::json)
-- curl 'http://127.0.0.1:8050/rpc/query'  -H 'Content-Profile: ogmios'   -H 'Content-Type: application/json' --data-raw $'{"query":"SELECT ogmios.submit_tx($1)","params":{"txHex":"84a500828258202c5b8b4f0a467e88286d64e239a29f224b4..."}}'




-- -- evaluateTx --
-- DROP FUNCTION IF EXISTS ogmios.evaluate_tx ;
-- CREATE OR REPLACE FUNCTION ogmios.evaluate_tx(params JSON) RETURNS JSON LANGUAGE SQL AS $BODY$ -- DEACTIVATED!
--         WITH s AS (
--         SELECT sql_private_extensions.post_json(
--                         'http://ogmios:1337/',
--                         FORMAT(
-- 				'{"params": {"transaction": {"cbor": "%s"},"additionalUtxo": [] },"method": "evaluateTransaction","jsonrpc": "2.0","id":"evaluateTransaction-%s"}',
--                                 params->>'txHex',
--                                 MD5(params->>'txHex')
--                         )::json
--                 )
--     ) SELECT * FROM s;
-- $BODY$
--     SECURITY DEFINER
--     -- Set a search_path with priorities to allow plugin schema users to use sql_private_extensions schema underneath this function
--     SET search_path = sql_private_extensions, ogmios;

-- Example usage --
-- SELECT * from ogmios.evaluate_tx('{"txHex":"84a70081825820bd47ba3d4219191c81c06c995e32852b0973e16f7fe7686145af3ae4df6a3a1702018282583900d8ad9311966>
-- curl 'http://127.0.0.1:8050/rpc/query'  -H 'Content-Profile: ogmios'   -H 'Content-Type: application/json' --data-raw $'{"query":"SELECT ogmios.evaluate_tx($1)","params":{"txHex":"84a500828258202c5b8b4f0a467e88286d64e239a29f224b4..."}}'








-- submitTx (using cardano-sql-companion REST API)--
-- DROP FUNCTION IF EXISTS ogmios.submit_tx ;
-- CREATE OR REPLACE FUNCTION ogmios.submit_tx(params JSON) RETURNS JSON LANGUAGE SQL AS $BODY$
--     WITH s AS (
--         SELECT sql_private_extensions.post_json('http://cardano-sql-companion:4000/ogmios/submit_tx',params)
--    ) SELECT * FROM s;
-- $BODY$
--     SECURITY DEFINER
--     -- Set a search_path with priorities to allow plugin schema users to use sql_private_extensions schema underneath this function
--     SET search_path = sql_private_extensions, ogmios;
-- Example usage --
-- curl 'http://127.0.0.1:8050/rpc/query'  -H 'Content-Profile: ogmios'   -H 'Content-Type: application/json' --data-raw $'{"query":"SELECT ogmios.submit_tx($1)","params":{"txHex":"84a500828258202c5b8b4f0a467e88286d64e239a29f224b4..."}}'


-- evaluateTx (using cardano-sql-companion REST API) --
-- DROP FUNCTION IF EXISTS ogmios.evaluate_tx ;
-- CREATE OR REPLACE FUNCTION ogmios.evaluate_tx(params JSON) RETURNS JSON LANGUAGE SQL AS $BODY$
--     WITH s AS (
--        SELECT sql_private_extensions.post_json('http://cardano-sql-companion:4000/ogmios/evaluate_tx',params)
--    ) SELECT * FROM s;
--$BODY$
--    SECURITY DEFINER
--    -- Set a search_path with priorities to allow plugin schema users to use sql_private_extensions schema underneath this function
--    SET search_path = sql_private_extensions, ogmios;

-- Example usage --
-- curl 'http://127.0.0.1:8050/rpc/query'  -H 'Content-Profile: ogmios'   -H 'Content-Type: application/json' --data-raw $'{"query":"SELECT ogmios.evaluate_tx($1)","params":{"txHex":"84a500828258202c5b8b4f0a467e88286d64e239a29f224b4"}}'





-- USERS
-- Lets apply SELECT only permissions to these users for ogmios
SELECT sql_private_extensions.grant_read_only_access('web_anon, authenticator', 'ogmios');

