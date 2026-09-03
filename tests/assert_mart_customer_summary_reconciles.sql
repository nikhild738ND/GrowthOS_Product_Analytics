with mart_totals as (

    select
        count(*) as user_count,
        sum(order_count) as order_count,
        sum(lifetime_revenue_usd) as revenue_usd

    from {{ ref('mart_customer_summary') }}
),

source_totals as (

    select
        count(*) as user_count,
        sum(order_count) as order_count,
        sum(lifetime_revenue_usd) as revenue_usd

    from {{ ref('int_users') }}
)

select
    mart_totals.user_count as mart_users,
    source_totals.user_count as source_users,

    mart_totals.order_count as mart_orders,
    source_totals.order_count as source_orders,

    mart_totals.revenue_usd as mart_revenue,
    source_totals.revenue_usd as source_revenue

from mart_totals

cross join source_totals

where
    mart_totals.user_count != source_totals.user_count

    or mart_totals.order_count != source_totals.order_count

    or abs(
        mart_totals.revenue_usd
        - source_totals.revenue_usd
    ) > 0.01