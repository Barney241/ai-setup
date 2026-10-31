SELECT
    p.period AS period,
    r.requests AS requests,
    r.tokens AS tokens,
    r.api_usd AS api_usd,
    r.tasks AS tasks,
    r.cache_hit AS cache_hit,
    r.ttft_p95_ms AS ttft_p95_ms,
    r.model_minutes AS model_minutes,
    q.prompts AS prompts,
    q.prompted_tasks AS prompted_tasks,
    q.one_prompt_tasks AS one_prompt_tasks,
    t.tool_calls AS tool_calls,
    t.tool_failures AS tool_failures,
    w.tool_minutes AS tool_minutes,
    w.wait_minutes AS wait_minutes,
    e.api_errors AS api_errors,
    o.commits AS commits,
    o.pull_requests AS pull_requests,
    o.lines_changed AS lines_changed
FROM (SELECT arrayJoin(['current', 'previous']) AS period) AS p
LEFT JOIN
(
    SELECT
        if(ts >= now() - toIntervalDay({days:UInt32}), 'current', 'previous') AS period,
        count() AS requests,
        sum(input_tokens + output_tokens + cached_tokens + cache_write_tokens) AS tokens,
        sum(cost_usd) AS api_usd,
        uniqExact(session_id) AS tasks,
        sum(cached_tokens) / nullIf(sum(input_tokens + cached_tokens + cache_write_tokens), 0) AS cache_hit,
        quantileIf(0.95)(ttft_ms, ttft_ms > 0) AS ttft_p95_ms,
        sum(duration_ms) / 60000 AS model_minutes
    FROM ai.requests
    WHERE ts >= now() - toIntervalDay({days:UInt32} * 2) AND session_id IN scoped
    GROUP BY period
) AS r ON p.period = r.period
LEFT JOIN
(
    SELECT
        period,
        sum(session_prompts) AS prompts,
        count() AS prompted_tasks,
        countIf(session_prompts = 1) AS one_prompt_tasks
    FROM
    (
        SELECT
            if(ts >= now() - toIntervalDay({days:UInt32}), 'current', 'previous') AS period,
            session_id,
            count() AS session_prompts
        FROM ai.prompts
        WHERE ts >= now() - toIntervalDay({days:UInt32} * 2) AND session_id IN scoped
        GROUP BY period, session_id
    )
    GROUP BY period
) AS q ON p.period = q.period
LEFT JOIN
(
    SELECT
        if(ts >= now() - toIntervalDay({days:UInt32}), 'current', 'previous') AS period,
        count() AS tool_calls,
        countIf(NOT success) AS tool_failures
    FROM ai.tools
    WHERE ts >= now() - toIntervalDay({days:UInt32} * 2)
        AND NOT (agent = 'codex' AND tool = 'exec')
        AND session_id IN scoped
    GROUP BY period
) AS t ON p.period = t.period
LEFT JOIN
(
    SELECT
        if(ts >= now() - toIntervalDay({days:UInt32}), 'current', 'previous') AS period,
        sumIf(duration_ms, phase = 'tool') / 60000 AS tool_minutes,
        sumIf(duration_ms, phase = 'permission_wait' AND name NOT LIKE 'config:%') / 60000 AS wait_minutes
    FROM ai.timings
    WHERE ts >= now() - toIntervalDay({days:UInt32} * 2) AND session_id IN scoped
    GROUP BY period
) AS w ON p.period = w.period
LEFT JOIN
(
    SELECT
        if(ts >= now() - toIntervalDay({days:UInt32}), 'current', 'previous') AS period,
        count() AS api_errors
    FROM ai.api_errors
    WHERE ts >= now() - toIntervalDay({days:UInt32} * 2) AND session_id IN scoped
    GROUP BY period
) AS e ON p.period = e.period
LEFT JOIN
(
    SELECT
        if(TimeUnix >= now() - toIntervalDay({days:UInt32}), 'current', 'previous') AS period,
        sumIf(Value, MetricName = 'claude_code.commit.count') AS commits,
        sumIf(Value, MetricName = 'claude_code.pull_request.count') AS pull_requests,
        sumIf(Value, MetricName = 'claude_code.lines_of_code.count') AS lines_changed
    FROM otel.otel_metrics_sum
    WHERE TimeUnix >= now() - toIntervalDay({days:UInt32} * 2)
        AND ServiceName = 'claude-code'
        AND Attributes['session.id'] IN scoped
    GROUP BY period
) AS o ON p.period = o.period
