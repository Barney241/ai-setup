SELECT
    agent,
    model,
    count() AS requests,
    uniqExact(session_id) AS sessions,
    sum(input_tokens) AS input,
    sum(output_tokens) AS output,
    sum(cached_tokens) AS cached,
    sum(cache_write_tokens) AS cache_written,
    round(cached / nullIf(input + cached + cache_written, 0), 3) AS cache_hit_ratio,
    round(sum(cost_usd), 2) AS api_equivalent_usd,
    round(avg(ttft_ms)) AS avg_ttft_ms
FROM ai.requests
WHERE ts >= now() - INTERVAL {days:UInt32} DAY
GROUP BY agent, model
ORDER BY input + output + cached DESC
