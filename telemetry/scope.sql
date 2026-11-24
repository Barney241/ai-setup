WITH
({project:String} = '' AND {host:String} = '' AND {agent:String} = '') AS unfiltered,
scoped AS
(
    SELECT session_id
    FROM ai.events
    WHERE ts >= now() - toIntervalDay({days:UInt32} * 2)
        AND session_id != ''
        AND ({host:String} = '' OR host = {host:String})
        AND ({agent:String} = '' OR agent = {agent:String})
        AND (
            {project:String} = ''
            OR ({project:String} = 'unattributed' AND session_id NOT IN (SELECT session_id FROM ai.session_context WHERE project != ''))
            OR session_id IN (SELECT session_id FROM ai.session_context WHERE project = {project:String})
        )
    GROUP BY session_id
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
                tool IN ('Bash', 'exec_command', 'run_command'),
                if(
                    JSONExtractString(input, 'command') != '',
                    JSONExtractString(input, 'command'),
                    if(JSONExtractString(input, 'cmd') != '', JSONExtractString(input, 'cmd'), JSONExtractString(input, 'CommandLine'))
                ),
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
