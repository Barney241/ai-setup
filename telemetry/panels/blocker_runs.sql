SELECT
    toString(toDateTime(b.ts)) AS at,
    b.session_id AS session_id,
    b.detail AS detail,
    b.failed AS failed,
    b.duration_ms / 1000 AS seconds,
    t.project AS project,
    t.task AS task
FROM blocker_events AS b
LEFT JOIN ai.tasks AS t ON b.session_id = t.session_id
WHERE b.ts >= now() - toIntervalDay({days:UInt32})
    AND b.session_id IN scoped
    AND b.kind = {kind:String}
    AND b.name = {name:String}
ORDER BY b.duration_ms DESC, b.ts DESC
LIMIT 50
