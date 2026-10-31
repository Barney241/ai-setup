SELECT
    r.provider AS provider,
    r.delegated AS delegated,
    r.completed AS completed,
    r.cancelled AS cancelled,
    h.queue_seconds AS queue_seconds,
    h.run_seconds AS run_seconds
FROM
(
    SELECT
        provider,
        delegated,
        sumIf(increase, outcome = 'completed') AS completed,
        sumIf(increase, outcome = 'cancelled') AS cancelled
    FROM
    (
        SELECT
            Attributes['provider'] AS provider,
            Attributes['delegated'] AS delegated,
            Attributes['outcome'] AS outcome,
            max(Value) - if(StartTimeUnix >= now() - toIntervalDay({days:UInt32}), 0, min(Value)) AS increase
        FROM otel.otel_metrics_sum
        WHERE MetricName = 't3_runs_total' AND TimeUnix >= now() - toIntervalDay({days:UInt32})
        GROUP BY provider, delegated, outcome, Attributes['modelFamily'], ResourceAttributes['host.name'], StartTimeUnix
    )
    GROUP BY provider, delegated
) AS r
LEFT JOIN
(
    SELECT
        provider,
        delegated,
        sumIf(total_ms, MetricName = 't3_run_queue_wait') / nullIf(sumIf(runs, MetricName = 't3_run_queue_wait'), 0) / 1000 AS queue_seconds,
        sumIf(total_ms, MetricName = 't3_run_duration') / nullIf(sumIf(runs, MetricName = 't3_run_duration'), 0) / 1000 AS run_seconds
    FROM
    (
        SELECT
            MetricName,
            Attributes['provider'] AS provider,
            Attributes['delegated'] AS delegated,
            max(Count) - if(StartTimeUnix >= now() - toIntervalDay({days:UInt32}), 0, min(Count)) AS runs,
            max(Sum) - if(StartTimeUnix >= now() - toIntervalDay({days:UInt32}), 0, min(Sum)) AS total_ms
        FROM otel.otel_metrics_histogram
        WHERE MetricName IN ('t3_run_queue_wait', 't3_run_duration') AND TimeUnix >= now() - toIntervalDay({days:UInt32})
        GROUP BY MetricName, provider, delegated, Attributes['modelFamily'], Attributes['outcome'], ResourceAttributes['host.name'], StartTimeUnix
    )
    GROUP BY provider, delegated
) AS h ON r.provider = h.provider AND r.delegated = h.delegated
ORDER BY completed DESC
