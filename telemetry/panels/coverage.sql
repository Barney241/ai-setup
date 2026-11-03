SELECT
    f.host AS host,
    f.failures AS failures,
    f.detailed AS detailed,
    s.sessions AS sessions,
    s.titled AS titled
FROM
(
    SELECT host, count() AS failures, countIf(error != 'Shell command failed') AS detailed
    FROM ai.tool_failures
    WHERE ts >= now() - toIntervalDay({days:UInt32})
    GROUP BY host
) AS f
FULL JOIN
(
    SELECT e.host AS host, uniqExact(e.session_id) AS sessions, uniqExactIf(e.session_id, c.t3_title != '') AS titled
    FROM ai.events AS e
    LEFT JOIN ai.session_context AS c ON e.session_id = c.session_id
    WHERE e.ts >= now() - toIntervalDay({days:UInt32}) AND e.session_id != ''
    GROUP BY e.host
) AS s ON f.host = s.host
ORDER BY sessions DESC
