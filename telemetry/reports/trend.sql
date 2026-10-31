SELECT
    toString(toDate(ts)) AS day,
    sum(input_tokens + output_tokens + cached_tokens + cache_write_tokens) AS total_tokens,
    round(sum(cost_usd), 2) AS api_usd
FROM ai.requests
WHERE toDate(ts) > today() - {days:UInt32} * 2
GROUP BY day
ORDER BY day
