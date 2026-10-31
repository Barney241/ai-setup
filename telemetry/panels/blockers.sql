SELECT
    kind,
    name,
    count() AS events,
    sum(failed) AS failures,
    sum(duration_ms) / 60000 AS minutes,
    quantile(0.95)(duration_ms) / 1000 AS p95_seconds,
    max(duration_ms) / 1000 AS longest_seconds
FROM blocker_events
WHERE ts >= now() - toIntervalDay({days:UInt32}) AND session_id IN scoped
GROUP BY kind, name
ORDER BY minutes DESC, failures DESC
LIMIT 10
