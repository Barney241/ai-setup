SELECT
    skill,
    trigger,
    count() AS activations,
    uniqExact(activated.session_id) AS sessions,
    round(avg(s.prompts), 1) AS avg_prompts_per_session,
    countIf(s.prompts <= 1) AS one_prompt_sessions,
    round(avg(s.tool_failures), 1) AS avg_tool_failures_per_session
FROM ai.skills AS activated
LEFT JOIN ai.sessions AS s ON activated.session_id = s.session_id
WHERE activated.ts >= now() - INTERVAL {days:UInt32} DAY
GROUP BY skill, trigger
ORDER BY activations DESC
