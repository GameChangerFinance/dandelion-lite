SELECT json_agg(t) FROM (
    SELECT
        query,
        calls,
        total_exec_time,
        (total_exec_time / calls) AS avg_time_per_call
    FROM pg_stat_statements
    ORDER BY avg_time_per_call DESC
    LIMIT 10
) t;

