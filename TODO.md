
# TODO

## Code of conduct:
- keep it always as simple as possible for end users and for maintainers
- avoid creating new files as possible
- avoid creating new mandatory env vars as possible
- if new files need to be created, nest them under the stablished root directories
- fully base the deployment on single .env file and docker-compose.yaml as backbone
- multiple .env.example files could be created for different project names (networks) 
- minimize changes on koios-lite, koios-artifact, and other popular project's original files

## Goals:
- make easier to pull changes from koios-lite, koios-artifact, and other popular project's to maintain the project
- make services modular and optional for end users
- in the future containers, SQL and CRON extensions will be enabled/disabled from dandoman.sh menu

---

## Tasks:

### Initial base
- [x] added ogmios
- [x] added unimatrix
- [x] added pgadmin
- [x] enabled swagger
- [x] exposed public schema and `$SCHEMA` on postgrest
- [x] kept koios-lite API SQL and CRON files enabled
- [x] preloaded some disabled CRON and SQL extensions from 
- [x] cardano-graphql
- [x] koios-artifacts (koios)
    - custom ones for gcw development and tests
- [x] gum color codes on images/ for menu development
- [x] new logo, TODO.md, pics, and some docs

### scripts/dandoman.sh menu
- [x] added ogmios functions
- [x] added unimatrix functions
- [x] added postgres db volume removal function
- [x] fixed bugs on table list generator

### Ogmios
- [ ] Fix error preventing ogmios container to start. In logs: `Failed to decode JSON (or YAML) file: InvalidYaml (Just (YamlException "Yaml file not found: /opt/cardano/cnode/files/byron-genesis.json"))`. 
Solution: make the exported config files from cardano-node accessible to ogmios. 
- [ ] Check that if formatting issues appear with this config files, make ogmios version match cardano-node version

### Unimatrix
- [ ] Check that UNIMATRIX_PORT is reaching the js file properly

### Pgadmin4
- [ ] fix SANITIZED_EMAIL escaping bug on customized entrypoint in docker-compose.yaml without creating extra files nor extra env vars - minimal file footprint
- [ ] make servers.json get loaded automatically. File is getting created but not loaded on boot

### Minimal SQL and CRON extensions for test-case GCFS Headers
- [ ] on a separate branch
- [ ] remove all SQL and CRON jobs properly (comment cron job lines on entrypoint files)
- [ ] create customized, and apply existing from koios-artifacts and koios, the minimal set of SQL and CRON elements to allow GCFS queries. New keys and relations over `public` schema, if other elements are needed, on `{{SCHEMA}}`. 
- [ ] Use ERD diagrams on Pgadmin4 to design/review relationships 
- [ ] Make POC using [postgrest client lib](https://supabase.com/docs/reference/javascript/installing) (on codepen?)
