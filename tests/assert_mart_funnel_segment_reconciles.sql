with mart_totals as (

    select
        sum(total_sessions) as total_sessions,
        sum(order_count) as total_orders,
        sum(revenue_usd) as revenue_usd

    from {{ ref('mart_funnel_segment') }}

),

source_totals as (

    select
        (
            select count(*)
            from {{ ref('int_session_funnel') }}
        ) as total_sessions,

        (
            select count(*)
            from {{ ref('int_orders') }}
        ) as total_orders,

        (
            select coalesce(
                sum(order_revenue_usd),
                0
            )
            from {{ ref('int_orders') }}
        ) as revenue_usd

)

select
    mart_totals.total_sessions as mart_sessions,
    source_totals.total_sessions as source_sessions,

    mart_totals.total_orders as mart_orders,
    source_totals.total_orders as source_orders,

    mart_totals.revenue_usd as mart_revenue,
    source_totals.revenue_usd as source_revenue

from mart_totals

cross join source_totals

where
    mart_totals.total_sessions != source_totals.total_sessions

    or mart_totals.total_orders != source_totals.total_orders

    or abs(
        mart_totals.revenue_usd
        - source_totals.revenue_usd
    ) > 0.01