SELECT json_agg(t)
FROM (
    SELECT
        calls,
        shared_blks_hit,
        shared_blks_read,
        (shared_blks_read + shared_blks_hit) AS total_blocks,
        query
    FROM pg_stat_statements
    ORDER BY shared_blks_read DESC
    LIMIT 10
) t;