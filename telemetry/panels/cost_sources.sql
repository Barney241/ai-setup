SELECT
    toString(toDate(ts)) AS day,
    multiIf(
        source = 'compact', 'compaction',
        source LIKE 'agent:%', 'subagents',
        'main'
    ) AS source_group,
    sum(cost_usd) AS api_usd,
    count() AS requests
FROM ai.requests
WHERE toDate(ts) > today() - {days:UInt32}
    AND cost_usd IS NOT NULL
    AND (unfiltered AND session_id != '' OR session_id IN scoped)
GROUP BY day, source_group
ORDER BY day, source_group
