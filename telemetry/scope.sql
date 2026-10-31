WITH
scoped AS
(
    SELECT s.session_id
    FROM ai.sessions AS s
    LEFT JOIN ai.session_context AS c ON s.session_id = c.session_id
    WHERE ({project:String} = '' OR if(c.project = '', 'unattributed', c.project) = {project:String})
        AND ({host:String} = '' OR s.host = {host:String})
        AND ({agent:String} = '' OR s.agent = {agent:String})
),
blocker_events AS
(
    SELECT
        ts,
        session_id,
        if(shell != '', 'command', 'tool') AS kind,
        if(shell != '', arrayStringConcat(arraySlice(splitByWhitespace(shell), 1, 2), ' '), tool) AS name,
        substring(shell, 1, 400) AS detail,
        toUInt64(NOT success) AS failed,
        duration_ms
    FROM
    (
        SELECT
            ts, session_id, tool, success, duration_ms,
            if(
                tool IN ('Bash', 'exec_command'),
                if(JSONExtractString(input, 'command') != '', JSONExtractString(input, 'command'), JSONExtractString(input, 'cmd')),
                ''
            ) AS shell
        FROM ai.tools
        WHERE NOT (agent = 'codex' AND tool = 'exec')
    )
    UNION ALL
    SELECT ts, session_id, 'permission' AS kind, name, '' AS detail, toUInt64(0) AS failed, duration_ms
    FROM ai.timings
    WHERE phase = 'permission_wait' AND name NOT LIKE 'config:%'
    UNION ALL
    SELECT ts, session_id, 'api_error' AS kind, model AS name, substring(detail, 1, 400) AS detail, toUInt64(1) AS failed, toUInt64(0) AS duration_ms
    FROM ai.api_errors
)
