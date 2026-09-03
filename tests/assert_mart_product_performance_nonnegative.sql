select
    product_daily_id,
    metric_date,
    product_key,

    view_item_events,
    view_item_sessions,

    add_to_cart_events,
    add_to_cart_sessions,

    order_count,
    units_purchased,
    product_revenue_usd

from {{ ref('mart_product_performance') }}

where
    view_item_events < 0

    or view_item_sessions < 0

    or add_to_cart_events < 0

    or add_to_cart_sessions < 0

    or order_count < 0

    or units_purchased < 0

    or product_revenue_usd < 0