SELECT
    project,
    branch,
    agent,
    host,
    task,
    toString(toStartOfMinute(started)) AS started_at,
    dateDiff('minute', started, ended) AS minutes,
    prompts,
    tool_calls,
    tool_failures,
    total_tokens AS tokens,
    round(api_usd, 2) AS api_usd,
    round(tool_minutes, 2) AS tool_minutes
FROM ai.tasks
WHERE started >= now() - toIntervalDay({days:UInt32}) AND total_tokens > 0
ORDER BY total_tokens DESC
LIMIT 25
