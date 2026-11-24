SELECT
    toString(toDate(ts)) AS day,
    count() AS failures,
    countIf(error != 'Shell command failed') AS detailed
FROM ai.tool_failures
WHERE toDate(ts) > today() - {days:UInt32} * 2 AND (unfiltered AND session_id != '' OR session_id IN scoped)
GROUP BY day
ORDER BY day
