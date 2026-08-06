with row_counts as (

    select
        (
            select count(*)
            from {{ ref('int_sessions') }}
        ) as int_sessions_rows,

        (
            select count(*)
            from {{ ref('int_session_funnel') }}
        ) as int_session_funnel_rows
)

select
    int_sessions_rows,
    int_session_funnel_rows

from row_counts

where
    int_sessions_rows != int_session_funnel_rows