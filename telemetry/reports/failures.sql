SELECT
    ts, host, 'claude' AS agent, 'tool' AS kind, tool AS name,
    t3_title AS thread,
    substring(concat(command, ' => ', error_type, ': ', error), 1, 400) AS detail
FROM ai.tool_failures
WHERE ts >= now() - INTERVAL {days:UInt32} DAY
UNION ALL
SELECT ts, host, agent, 'tool' AS kind, tool AS name, '' AS thread, substring(input, 1, 200) AS detail
FROM ai.tools
WHERE NOT success AND agent = 'codex' AND ts >= now() - INTERVAL {days:UInt32} DAY
UNION ALL
SELECT ts, host, agent, 'api' AS kind, model AS name, '' AS thread, substring(detail, 1, 200) AS detail
FROM ai.api_errors
WHERE ts >= now() - INTERVAL {days:UInt32} DAY
UNION ALL
SELECT ts, host, 'claude' AS agent, 'hook' AS kind, hook AS name, '' AS thread, substring(reason, 1, 200) AS detail
FROM ai.hook_blocks
WHERE ts >= now() - INTERVAL {days:UInt32} DAY
ORDER BY ts DESC
LIMIT 50
