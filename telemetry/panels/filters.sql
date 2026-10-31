SELECT dimension, value
FROM
(
    SELECT 'project' AS dimension, project AS value, total_tokens FROM ai.tasks
    UNION ALL
    SELECT 'host' AS dimension, host AS value, total_tokens FROM ai.tasks
    UNION ALL
    SELECT 'agent' AS dimension, agent AS value, total_tokens FROM ai.tasks
)
WHERE total_tokens > 0 AND value != ''
GROUP BY dimension, value
ORDER BY dimension, value
