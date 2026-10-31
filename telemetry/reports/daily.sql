SELECT
    toDate(ts) AS day,
    agent,
    count() AS requests,
    uniqExact(session_id) AS sessions,
    sum(input_tokens + output_tokens + cached_tokens + cache_write_tokens) AS total_tokens,
    round(sum(cached_tokens) / nullIf(sum(input_tokens + cached_tokens + cache_write_tokens), 0), 3) AS cache_hit_ratio,
    round(sum(cost_usd), 2) AS api_equivalent_usd
FROM ai.requests
WHERE ts >= now() - INTERVAL {days:UInt32} DAY
GROUP BY day, agent
ORDER BY day DESC, agent
