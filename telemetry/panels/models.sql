SELECT
    agent,
    model,
    count() AS requests,
    sum(input_tokens + output_tokens + cached_tokens + cache_write_tokens) AS tokens,
    sum(cost_usd) AS api_usd,
    sum(cached_tokens) / nullIf(sum(input_tokens + cached_tokens + cache_write_tokens), 0) AS cache_hit,
    quantileIf(0.95)(ttft_ms, ttft_ms > 0) AS ttft_p95_ms
FROM ai.requests
WHERE ts >= now() - toIntervalDay({days:UInt32}) AND session_id IN scoped
GROUP BY agent, model
ORDER BY tokens DESC
LIMIT 20
