SELECT
    r.period AS period,
    r.total_tokens AS total_tokens,
    r.api_usd AS api_usd,
    r.sessions AS sessions,
    r.cache_hit_ratio AS cache_hit_ratio,
    t.tool_calls AS tool_calls,
    t.tool_failures AS tool_failures,
    w.tool_minutes AS tool_minutes,
    w.permission_minutes AS permission_minutes
FROM
(
    SELECT
        if(ts >= now() - toIntervalDay({days:UInt32}), 'current', 'previous') AS period,
        sum(input_tokens + output_tokens + cached_tokens + cache_write_tokens) AS total_tokens,
        round(sum(cost_usd), 2) AS api_usd,
        uniqExact(session_id) AS sessions,
        round(sum(cached_tokens) / nullIf(sum(input_tokens + cached_tokens + cache_write_tokens), 0), 3) AS cache_hit_ratio
    FROM ai.requests
    WHERE ts >= now() - toIntervalDay({days:UInt32} * 2)
    GROUP BY period
) AS r
LEFT JOIN
(
    SELECT
        if(ts >= now() - toIntervalDay({days:UInt32}), 'current', 'previous') AS period,
        count() AS tool_calls,
        countIf(NOT success) AS tool_failures
    FROM ai.tools
    WHERE ts >= now() - toIntervalDay({days:UInt32} * 2) AND NOT (agent = 'codex' AND tool = 'exec')
    GROUP BY period
) AS t ON r.period = t.period
LEFT JOIN
(
    SELECT
        if(ts >= now() - toIntervalDay({days:UInt32}), 'current', 'previous') AS period,
        round(sumIf(duration_ms, phase = 'tool') / 60000, 2) AS tool_minutes,
        round(sumIf(duration_ms, phase = 'permission_wait' AND name NOT LIKE 'config:%') / 60000, 2) AS permission_minutes
    FROM ai.timings
    WHERE ts >= now() - toIntervalDay({days:UInt32} * 2)
    GROUP BY period
) AS w ON r.period = w.period
