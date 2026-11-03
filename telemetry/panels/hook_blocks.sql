SELECT
    hook,
    substring(reason, 1, 140) AS reason,
    count() AS blocks,
    toString(toDateTime(max(ts))) AS last_seen
FROM ai.hook_blocks
WHERE ts >= now() - toIntervalDay({days:UInt32}) AND session_id IN scoped
GROUP BY hook, reason
ORDER BY blocks DESC
LIMIT 15
