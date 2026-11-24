SELECT
    tool,
    error_type,
    substring(replaceRegexpAll(splitByChar('\n', error)[1], '[0-9]{3,}', 'N'), 1, 140) AS message,
    count() AS failures,
    uniqExact(session_id) AS sessions,
    toString(toDateTime(max(ts))) AS last_seen
FROM ai.tool_failures
WHERE ts >= now() - toIntervalDay({days:UInt32}) AND (unfiltered AND session_id != '' OR session_id IN scoped)
GROUP BY tool, error_type, message
ORDER BY failures DESC
LIMIT 15
