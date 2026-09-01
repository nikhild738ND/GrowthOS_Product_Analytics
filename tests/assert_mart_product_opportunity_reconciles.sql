with mart_totals as (

    select
        sum(view_item_sessions) as view_item_sessions,
        sum(add_to_cart_sessions) as add_to_cart_sessions,
        sum(order_count) as order_count,
        sum(units_purchased) as units_purchased,
        sum(product_revenue_usd) as product_revenue_usd

    from {{ ref('mart_product_opportunity') }}
),

source_totals as (

    select
        sum(view_item_sessions) as view_item_sessions,
        sum(add_to_cart_sessions) as add_to_cart_sessions,
        sum(order_count) as order_count,
        sum(units_purchased) as units_purchased,
        sum(product_revenue_usd) as product_revenue_usd

    from {{ ref('mart_product_performance') }}
)

select
    mart_totals.*,

    source_totals.view_item_sessions
        as source_view_item_sessions,

    source_totals.add_to_cart_sessions
        as source_add_to_cart_sessions,

    source_totals.order_count
        as source_order_count,

    source_totals.units_purchased
        as source_units_purchased,

    source_totals.product_revenue_usd
        as source_product_revenue_usd

from mart_totals

cross join source_totals

where
    mart_totals.view_item_sessions
        != source_totals.view_item_sessions

    or mart_totals.add_to_cart_sessions
        != source_totals.add_to_cart_sessions

    or mart_totals.order_count
        != source_totals.order_count

    or mart_totals.units_purchased
        != source_totals.units_purchased

    or abs(
        mart_totals.product_revenue_usd
        - source_totals.product_revenue_usd
    ) > 0.01