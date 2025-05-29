# CRON Jobs

## What's this?

A system that allows you to schedule recurrent tasks to maintain, shape and control various services like `koios-artifacts`, `koios-lite`,`duckdns`,`dbless-cardano-token-registry` and more.

The script files in this directory are scheduled with `cron`.

## Rules

- Each service jobs are scheduled in `scripts/cron/<SERVICE_NAME>/init_cron` and this file follows `cron` time format. This tool may be useful [Cron Online Calculator](https://crontab.cronhub.io/). 
- All these `init_cron` files need to be registered as a line in `scripts/cron/entrypoint.sh` to be included in the container that runs the jobs. Line follows this format: `cat /etc/cron.d/<SERVICE_NAME>/init_cron  >> "$cronFile" && echo >>"$cronFile"`
- a master, unified, `scripts/cron/init_cron` file will be created automatically by the container, **do not edit it manually!!!**

## Notes

### Koios Artifacts

Update procedure for `scripts/cron/koios-artifacts-<VERSION>/`:
- Download and extract latest release from [koios artifacts](https://github.com/cardano-community/koios-artifacts/tags)
- copy `*.sh` files  (and dependencies if any) from `koios-artifacts-<VERSION>/files/grest/cron/jobs` into `scripts/cron/koios-artifacts-<VERSION>/`
- copy/update former `scripts/cron/koios-artifacts-<VERSION>/init_cron` file. Use previous version as boilerplate.
- environment variables injection (check working files as reference to learn how to do it):
    - replace `cexplorer` for `${POSTGRES_DB}`
    - replace `grest` or `GREST` postgresDb schema name to `${KOIOS_ARTIFACTS_SCHEMA}` 
    - adapt postgresDb calls with `${DB_NAME}` and `${POSTGRES_HOST}` environment variables, like `$(psql ${DB_NAME} -h ${POSTGRES_HOST} -c "select last_value from ${KOIOS_ARTIFACTS_SCHEMA}.control_table where key='asset_registry_commit'" -t | xargs)"`
- update `scripts/cron/entrypoint.sh` with the new updated `scripts/cron/koios-artifacts-<VERSION>/init_cron` file, like for example adding the line `cat /etc/cron.d/koios-artifacts-1.2.0/init_cron  >> "$cronFile" && echo >>"$cronFile"` and removing prior koios `init_cron` lines on that file
- update `KOIOS_VERSION` environment variable with new version number on `.env` and all `.env.example.<NETWORK>` files
- check for unexpected changes that require further actions.