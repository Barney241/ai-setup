CREATE DATABASE IF NOT EXISTS ai;

CREATE OR REPLACE VIEW ai.events AS
SELECT
    Timestamp AS ts,
    ResourceAttributes['host.name'] AS host,
    if(ServiceName LIKE 'codex%', 'codex', 'claude') AS agent,
    if(ServiceName LIKE 'codex%', LogAttributes['conversation.id'], LogAttributes['session.id']) AS session_id,
    LogAttributes['user.email'] AS account,
    if(Body != '', Body, LogAttributes['event.name']) AS event,
    LogAttributes AS attrs
FROM otel.otel_logs
WHERE ServiceName = 'claude-code' OR ServiceName LIKE 'codex%';

CREATE OR REPLACE VIEW ai.requests AS
SELECT
    ts, host, agent, session_id, account,
    attrs['model'] AS model,
    attrs['query_source'] AS source,
    toUInt64OrZero(attrs['input_tokens']) AS input_tokens,
    toUInt64OrZero(attrs['cache_read_tokens']) AS cached_tokens,
    toUInt64OrZero(attrs['cache_creation_tokens']) AS cache_write_tokens,
    toUInt64OrZero(attrs['output_tokens']) AS output_tokens,
    toFloat64OrNull(attrs['cost_usd']) AS cost_usd,
    toUInt64OrZero(attrs['ttft_ms']) AS ttft_ms,
    toUInt64OrZero(attrs['duration_ms']) AS duration_ms
FROM ai.events
WHERE event = 'claude_code.api_request'
UNION ALL
SELECT
    ts, host, agent, session_id, account,
    attrs['model'] AS model,
    attrs['originator'] AS source,
    toUInt64(greatest(toInt64OrZero(attrs['input_token_count']) - toInt64OrZero(attrs['cached_token_count']), 0)) AS input_tokens,
    toUInt64OrZero(attrs['cached_token_count']) AS cached_tokens,
    toUInt64OrZero(attrs['cache_write_token_count']) AS cache_write_tokens,
    toUInt64OrZero(attrs['output_token_count']) AS output_tokens,
    CAST(NULL, 'Nullable(Float64)') AS cost_usd,
    toUInt64OrZero(attrs['ttft_ms']) AS ttft_ms,
    toUInt64(0) AS duration_ms
FROM ai.events
WHERE event = 'codex.sse_event' AND attrs['event.kind'] = 'response.completed';

CREATE OR REPLACE VIEW ai.prompts AS
SELECT
    ts, host, agent, session_id, account,
    attrs['prompt'] AS prompt,
    toUInt64OrZero(attrs['prompt_length']) AS prompt_length
FROM ai.events
WHERE event IN ('claude_code.user_prompt', 'codex.user_prompt');

CREATE OR REPLACE VIEW ai.responses AS
SELECT
    ts, host, agent, session_id, account,
    attrs['model'] AS model,
    attrs['response'] AS response
FROM ai.events
WHERE event = 'claude_code.assistant_response';

CREATE OR REPLACE VIEW ai.tools AS
SELECT
    ts, host, agent, session_id, account,
    attrs['tool_name'] AS tool,
    attrs['success'] = 'true' AS success,
    toUInt64OrZero(attrs['duration_ms']) AS duration_ms,
    if(event = 'codex.tool_result', attrs['arguments'], attrs['tool_input']) AS input,
    attrs['output'] AS output
FROM ai.events
WHERE event IN ('claude_code.tool_result', 'codex.tool_result');

CREATE OR REPLACE VIEW ai.skills AS
SELECT
    ts, host, agent, session_id, account,
    attrs['skill.name'] AS skill,
    attrs['skill.source'] AS source,
    attrs['invocation_trigger'] AS trigger
FROM ai.events
WHERE event = 'claude_code.skill_activated';

CREATE OR REPLACE VIEW ai.api_errors AS
SELECT
    ts, host, agent, session_id, account,
    attrs['model'] AS model,
    toJSONString(mapFilter((key, value) -> key NOT IN ('user.email', 'user.id', 'user.account_id', 'user.account_uuid', 'organization.id'), attrs)) AS detail
FROM ai.events
WHERE event = 'claude_code.api_error';

CREATE OR REPLACE VIEW ai.sessions AS
SELECT
    session_id,
    any(agent) AS agent,
    any(host) AS host,
    any(account) AS account,
    min(ts) AS started,
    max(ts) AS ended,
    countIf(event IN ('claude_code.user_prompt', 'codex.user_prompt')) AS prompts,
    countIf(event IN ('claude_code.tool_result', 'codex.tool_result')) AS tool_calls,
    countIf(event IN ('claude_code.tool_result', 'codex.tool_result') AND attrs['success'] != 'true') AS tool_failures
FROM ai.events
WHERE session_id != ''
GROUP BY session_id;

CREATE OR REPLACE VIEW ai.timings AS
SELECT
    ts, host, agent, session_id, account,
    'tool' AS phase,
    tool AS name,
    substring(input, 1, 500) AS detail,
    duration_ms
FROM ai.tools
WHERE NOT (agent = 'codex' AND tool = 'exec')
UNION ALL
SELECT
    Timestamp AS ts,
    ResourceAttributes['host.name'] AS host,
    'claude' AS agent,
    SpanAttributes['session.id'] AS session_id,
    SpanAttributes['user.email'] AS account,
    if(SpanName = 'claude_code.llm_request', 'model', 'permission_wait') AS phase,
    if(SpanName = 'claude_code.llm_request', SpanAttributes['model'], concat(SpanAttributes['source'], ':', SpanAttributes['decision'])) AS name,
    '' AS detail,
    toUInt64(Duration / 1000000) AS duration_ms
FROM otel.otel_traces
WHERE SpanName IN ('claude_code.llm_request', 'claude_code.tool.blocked_on_user');

CREATE OR REPLACE VIEW ai.session_context AS
SELECT
    session_id,
    argMax(project, ts) AS project,
    argMax(branch, ts) AS branch
FROM
(
    SELECT
        Timestamp AS ts,
        LogAttributes['session.id'] AS session_id,
        LogAttributes['project'] AS project,
        LogAttributes['branch'] AS branch
    FROM otel.otel_logs
    WHERE ServiceName = 'ai-setup' AND Body = 'session_context'
    UNION ALL
    SELECT
        ts,
        session_id,
        if(
            extract(workdir, '/[.]t3/worktrees/([^/]+)/') != '',
            extract(workdir, '/[.]t3/worktrees/([^/]+)/'),
            splitByChar('/', trimRight(workdir, '/'))[-1]
        ) AS project,
        '' AS branch
    FROM
    (
        SELECT ts, session_id, JSONExtractString(input, 'workdir') AS workdir
        FROM ai.tools
        WHERE agent = 'codex'
    )
    WHERE workdir != ''
)
GROUP BY session_id;

CREATE OR REPLACE VIEW ai.tasks AS
SELECT
    s.session_id AS session_id,
    s.agent AS agent,
    s.host AS host,
    s.started AS started,
    s.ended AS ended,
    s.prompts AS prompts,
    s.tool_calls AS tool_calls,
    s.tool_failures AS tool_failures,
    if(c.project = '', 'unattributed', c.project) AS project,
    c.branch AS branch,
    p.task AS task,
    r.total_tokens AS total_tokens,
    r.api_usd AS api_usd,
    t.tool_minutes AS tool_minutes
FROM ai.sessions AS s
LEFT JOIN ai.session_context AS c ON s.session_id = c.session_id
LEFT JOIN
(
    SELECT session_id, argMin(substring(replaceRegexpAll(prompt, '[[:space:]]+', ' '), 1, 100), ts) AS task
    FROM ai.prompts
    GROUP BY session_id
) AS p ON s.session_id = p.session_id
LEFT JOIN
(
    SELECT
        session_id,
        sum(input_tokens + output_tokens + cached_tokens + cache_write_tokens) AS total_tokens,
        sum(cost_usd) AS api_usd
    FROM ai.requests
    GROUP BY session_id
) AS r ON s.session_id = r.session_id
LEFT JOIN
(
    SELECT session_id, sum(duration_ms) / 60000 AS tool_minutes
    FROM ai.timings
    WHERE phase = 'tool'
    GROUP BY session_id
) AS t ON s.session_id = t.session_id;
