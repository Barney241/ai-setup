SELECT
    project,
    countIf(started >= now() - toIntervalDay({days:UInt32})) AS tasks,
    sumIf(total_tokens, started >= now() - toIntervalDay({days:UInt32})) AS tokens,
    sumIf(total_tokens, started < now() - toIntervalDay({days:UInt32})) AS previous_tokens,
    sumIf(api_usd, started >= now() - toIntervalDay({days:UInt32})) AS api_usd,
    sumIf(tool_minutes, started >= now() - toIntervalDay({days:UInt32})) AS tool_minutes,
    sumIf(tool_calls, started >= now() - toIntervalDay({days:UInt32})) AS tool_calls,
    sumIf(tool_failures, started >= now() - toIntervalDay({days:UInt32})) AS tool_failures
FROM ai.tasks
WHERE started >= now() - toIntervalDay({days:UInt32} * 2)
    AND total_tokens > 0
    AND session_id IN scoped
GROUP BY project
HAVING tokens > 0
ORDER BY tokens DESC
LIMIT 20
