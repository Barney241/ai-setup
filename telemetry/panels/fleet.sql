SELECT
    host,
    agent,
    toString(toDateTime(min(ts))) AS first_seen,
    dateDiff('minute', max(ts), now()) AS minutes_since,
    countIf(ts >= now() - toIntervalDay(1)) AS events_today
FROM ai.events
WHERE host != ''
GROUP BY host, agent
ORDER BY minutes_since, host, agent
