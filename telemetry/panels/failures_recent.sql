SELECT
    toString(toDateTime(ts)) AS at,
    host,
    tool,
    error_type,
    substring(error, 1, 400) AS error,
    substring(if(JSONExtractString(command, 'command') != '', JSONExtractString(command, 'command'), command), 1, 240) AS command,
    project,
    t3_title,
    session_id
FROM ai.tool_failures
WHERE ts >= now() - toIntervalDay({days:UInt32}) AND session_id IN scoped
ORDER BY ts DESC
LIMIT 30
