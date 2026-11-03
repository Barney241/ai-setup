SELECT
    tool,
    count() AS calls,
    countIf(NOT success) AS failures,
    sum(duration_ms) / 60000 AS minutes,
    quantile(0.95)(duration_ms) / 1000 AS p95_seconds
FROM ai.tools
WHERE ts >= now() - toIntervalDay({days:UInt32})
    AND NOT (agent = 'codex' AND tool = 'exec')
    AND session_id IN scoped
GROUP BY tool
ORDER BY minutes DESC
LIMIT 10
