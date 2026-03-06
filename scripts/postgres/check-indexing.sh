source .env;

docker compose exec postgress psql -U "$POSTGRES_USER" -d postgres -c "
show max_connections;
show wal_level;
show max_wal_senders;
show synchronous_commit;
show maintenance_work_mem;
show max_parallel_maintenance_workers;
show max_parallel_workers;
show max_worker_processes;
show shared_buffers;
"
docker compose exec postgress psql -U "$POSTGRES_USER" -d postgres -c "
SELECT
  *
FROM pg_stat_progress_create_index;
"
