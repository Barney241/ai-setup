SELECT
    toString(toDateTime(ts)) AS at,
    kind,
    title,
    detail,
    duration_ms / 1000 AS seconds,
    tokens,
    api_usd,
    failed
FROM
(
    SELECT ts, 'prompt' AS kind, 'You' AS title, substring(prompt, 1, 600) AS detail, toUInt64(0) AS duration_ms, toUInt64(0) AS tokens, CAST(NULL, 'Nullable(Float64)') AS api_usd, toUInt8(0) AS failed
    FROM ai.prompts
    WHERE session_id = {session:String}
    UNION ALL
    SELECT ts, 'response' AS kind, 'Agent' AS title, substring(response, 1, 600) AS detail, toUInt64(0) AS duration_ms, toUInt64(0) AS tokens, CAST(NULL, 'Nullable(Float64)') AS api_usd, toUInt8(0) AS failed
    FROM ai.responses
    WHERE session_id = {session:String}
    UNION ALL
    SELECT ts, 'model' AS kind, model AS title, source AS detail, duration_ms, input_tokens + output_tokens + cached_tokens + cache_write_tokens AS tokens, cost_usd AS api_usd, toUInt8(0) AS failed
    FROM ai.requests
    WHERE session_id = {session:String}
    UNION ALL
    SELECT ts, 'tool' AS kind, tool AS title, substring(input, 1, 600) AS detail, duration_ms, toUInt64(0) AS tokens, CAST(NULL, 'Nullable(Float64)') AS api_usd, toUInt8(NOT success) AS failed
    FROM ai.tools
    WHERE session_id = {session:String}
    UNION ALL
    SELECT ts, 'wait' AS kind, name AS title, '' AS detail, duration_ms, toUInt64(0) AS tokens, CAST(NULL, 'Nullable(Float64)') AS api_usd, toUInt8(0) AS failed
    FROM ai.timings
    WHERE session_id = {session:String} AND phase = 'permission_wait' AND name NOT LIKE 'config:%'
    UNION ALL
    SELECT ts, 'error' AS kind, model AS title, substring(detail, 1, 600) AS detail, toUInt64(0) AS duration_ms, toUInt64(0) AS tokens, CAST(NULL, 'Nullable(Float64)') AS api_usd, toUInt8(1) AS failed
    FROM ai.api_errors
    WHERE session_id = {session:String}
)
ORDER BY ts
LIMIT 600
