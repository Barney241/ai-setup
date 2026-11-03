SELECT
    toString(toDate(ts)) AS day,
    countIf(decision = 'accept' AND source = 'config') AS auto_allowed,
    countIf(decision = 'accept' AND source != 'config') AS you_approved,
    countIf(decision = 'reject' AND source = 'hook') AS hook_blocked,
    countIf(decision = 'reject' AND source != 'hook') AS rejected
FROM ai.decisions
WHERE toDate(ts) > today() - {days:UInt32} AND session_id IN scoped
GROUP BY day
ORDER BY day
