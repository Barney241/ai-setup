SELECT
    agent,
    phase,
    count() AS events,
    round(sum(duration_ms) / 60000, 1) AS total_minutes,
    round(quantile(0.5)(duration_ms)) AS p50_ms,
    round(quantile(0.95)(duration_ms)) AS p95_ms,
    max(duration_ms) AS max_ms
FROM ai.timings
WHERE ts >= now() - INTERVAL {days:UInt32} DAY
GROUP BY agent, phase
ORDER BY total_minutes DESC
