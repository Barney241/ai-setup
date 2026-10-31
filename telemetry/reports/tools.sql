SELECT
    agent,
    tool,
    count() AS calls,
    countIf(NOT success) AS failures,
    round(countIf(NOT success) / count(), 3) AS failure_ratio,
    round(quantile(0.5)(duration_ms)) AS p50_ms,
    round(quantile(0.95)(duration_ms)) AS p95_ms
FROM ai.tools
WHERE ts >= now() - INTERVAL {days:UInt32} DAY
GROUP BY agent, tool
ORDER BY calls DESC
LIMIT 50
