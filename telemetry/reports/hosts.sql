SELECT
    host,
    agent,
    account,
    count() AS requests,
    uniqExact(session_id) AS sessions,
    sum(input_tokens + output_tokens + cached_tokens + cache_write_tokens) AS total_tokens,
    round(sum(cost_usd), 2) AS api_equivalent_usd,
    max(ts) AS last_seen
FROM ai.requests
WHERE ts >= now() - INTERVAL {days:UInt32} DAY
GROUP BY host, agent, account
ORDER BY total_tokens DESC
