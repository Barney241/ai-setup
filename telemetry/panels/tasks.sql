SELECT
    session_id,
    project,
    branch,
    agent,
    host,
    task,
    toString(toStartOfMinute(started)) AS started_at,
    dateDiff('second', started, ended) / 60 AS minutes,
    prompts,
    tool_calls,
    tool_failures,
    total_tokens AS tokens,
    api_usd,
    tool_minutes
FROM ai.tasks
WHERE started >= now() - toIntervalDay({days:UInt32})
    AND total_tokens > 0
    AND session_id IN scoped
ORDER BY total_tokens DESC
LIMIT 100
