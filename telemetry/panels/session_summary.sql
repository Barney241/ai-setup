SELECT
    session_id, project, branch, agent, host, task,
    toString(toDateTime(started)) AS started_at,
    dateDiff('second', started, ended) / 60 AS minutes,
    prompts, tool_calls, tool_failures,
    total_tokens AS tokens,
    api_usd,
    tool_minutes
FROM ai.tasks
WHERE session_id = {session:String}
LIMIT 1
