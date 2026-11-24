SELECT
    round(sum(cost_usd), 2) AS api_usd
FROM ai.requests
WHERE ts >= now() - toIntervalDay({days:UInt32})
    AND cost_usd IS NOT NULL
    AND (unfiltered AND session_id != '' OR session_id IN scoped)
GROUP BY session_id
HAVING api_usd > 0
ORDER BY api_usd
