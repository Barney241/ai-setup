SELECT
    project,
    countIf(started >= now() - toIntervalDay({days:UInt32})) AS sessions,
    sumIf(total_tokens, started >= now() - toIntervalDay({days:UInt32})) AS tokens,
    sumIf(total_tokens, started < now() - toIntervalDay({days:UInt32})) AS previous_tokens,
    round(sumIf(api_usd, started >= now() - toIntervalDay({days:UInt32})), 2) AS api_usd,
    round(sumIf(tool_minutes, started >= now() - toIntervalDay({days:UInt32})), 2) AS tool_minutes,
    sumIf(tool_failures, started >= now() - toIntervalDay({days:UInt32})) AS tool_failures
FROM ai.tasks
WHERE started >= now() - toIntervalDay({days:UInt32} * 2)
GROUP BY project
HAVING tokens > 0
ORDER BY tokens DESC
LIMIT 15
