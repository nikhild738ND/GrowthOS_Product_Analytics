with sequential_funnel as (

    select
        metric_date,
        stage_number,
        stage_sessions,

        lag(
            stage_sessions
        ) over (
            partition by metric_date
            order by stage_number
        ) as previous_stage_sessions

    from {{ ref('mart_funnel_daily') }}

    where funnel_type = 'Sequential'
)

select
    metric_date,
    stage_number,
    previous_stage_sessions,
    stage_sessions

from sequential_funnel

where
    previous_stage_sessions is not null
    and stage_sessions > previous_stage_sessions