SELECT
    kind,
    name,
    count() AS events,
    sum(failed) AS failures,
    round(sum(duration_ms) / 60000, 2) AS minutes,
    round(max(duration_ms) / 1000, 1) AS longest_seconds
FROM
(
    SELECT
        ts,
        if(shell != '', 'command', 'tool') AS kind,
        if(
            shell != '',
            arrayStringConcat(arraySlice(splitByWhitespace(shell), 1, 2), ' '),
            tool
        ) AS name,
        toUInt64(NOT success) AS failed,
        duration_ms
    FROM
    (
        SELECT
            ts, tool, success, duration_ms,
            if(
                tool IN ('Bash', 'exec_command'),
                if(JSONExtractString(input, 'command') != '', JSONExtractString(input, 'command'), JSONExtractString(input, 'cmd')),
                ''
            ) AS shell
        FROM ai.tools
        WHERE NOT (agent = 'codex' AND tool = 'exec')
    )
    UNION ALL
    SELECT ts, 'permission' AS kind, name, toUInt64(0) AS failed, duration_ms
    FROM ai.timings
    WHERE phase = 'permission_wait' AND name NOT LIKE 'config:%'
    UNION ALL
    SELECT ts, 'api_error' AS kind, model AS name, toUInt64(1) AS failed, toUInt64(0) AS duration_ms
    FROM ai.api_errors
)
WHERE ts >= now() - toIntervalDay({days:UInt32})
GROUP BY kind, name
ORDER BY minutes DESC, failures DESC
LIMIT 15
