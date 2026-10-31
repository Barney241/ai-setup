SELECT ts, host, agent, 'tool' AS kind, tool AS name, substring(input, 1, 200) AS detail
FROM ai.tools
WHERE NOT success AND ts >= now() - INTERVAL {days:UInt32} DAY
UNION ALL
SELECT ts, host, agent, 'api' AS kind, model AS name, substring(detail, 1, 200) AS detail
FROM ai.api_errors
WHERE ts >= now() - INTERVAL {days:UInt32} DAY
ORDER BY ts DESC
LIMIT 50
