SELECT
    ts,
    host,
    agent,
    name AS tool,
    round(duration_ms / 1000, 1) AS seconds,
    substring(detail, 1, 160) AS command
FROM ai.timings
WHERE phase = 'tool' AND ts >= now() - INTERVAL {days:UInt32} DAY
ORDER BY duration_ms DESC
LIMIT 30
