SELECT
    r.day AS day,
    r.agent AS agent,
    r.tokens AS tokens,
    r.api_usd AS api_usd,
    r.tasks AS tasks,
    r.cache_hit AS cache_hit,
    t.tool_calls AS tool_calls,
    t.tool_failures AS tool_failures
FROM
(
    SELECT
        toString(toDate(ts)) AS day,
        agent,
        sum(input_tokens + output_tokens + cached_tokens + cache_write_tokens) AS tokens,
        sum(cost_usd) AS api_usd,
        uniqExact(session_id) AS tasks,
        sum(cached_tokens) / nullIf(sum(input_tokens + cached_tokens + cache_write_tokens), 0) AS cache_hit
    FROM ai.requests
    WHERE toDate(ts) > today() - {days:UInt32} * 2 AND session_id IN scoped
    GROUP BY day, agent
) AS r
LEFT JOIN
(
    SELECT
        toString(toDate(ts)) AS day,
        agent,
        count() AS tool_calls,
        countIf(NOT success) AS tool_failures
    FROM ai.tools
    WHERE toDate(ts) > today() - {days:UInt32} * 2
        AND NOT (agent = 'codex' AND tool = 'exec')
        AND session_id IN scoped
    GROUP BY day, agent
) AS t ON r.day = t.day AND r.agent = t.agent
ORDER BY day, agent
