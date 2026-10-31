SELECT
    s.session_id,
    s.agent,
    s.host,
    s.started,
    dateDiff('minute', s.started, s.ended) AS minutes,
    s.prompts,
    s.tool_calls,
    s.tool_failures,
    r.total_tokens,
    r.api_equivalent_usd
FROM ai.sessions AS s
INNER JOIN
(
    SELECT
        session_id,
        sum(input_tokens + output_tokens + cached_tokens + cache_write_tokens) AS total_tokens,
        round(sum(cost_usd), 2) AS api_equivalent_usd
    FROM ai.requests
    GROUP BY session_id
) AS r ON s.session_id = r.session_id
WHERE s.started >= now() - INTERVAL {days:UInt32} DAY
ORDER BY r.total_tokens DESC
LIMIT 25
