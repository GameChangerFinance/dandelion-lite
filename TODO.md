
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
- make easier to pull changes from Cardano Graphql MKII, koios-artifact, and other popular project's to maintain the project
- make services modular and optional for end users
- in the future containers, SQL and CRON extensions will be enabled/disabled from dandoman.sh menu

---

## Tasks:

### Initial release
- [x] prepare repo for initial release