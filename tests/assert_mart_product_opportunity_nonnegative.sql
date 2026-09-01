select
    product_opportunity_id,
    product_key,
    view_item_sessions,
    add_to_cart_sessions,
    order_count,
    units_purchased,
    product_revenue_usd,
    conversion_gap_to_category,
    modeled_additional_orders_full_gap,
    modeled_revenue_opportunity_full_gap_usd

from {{ ref('mart_product_opportunity') }}

where
    view_item_sessions < 0

    or add_to_cart_sessions < 0

    or order_count < 0

    or units_purchased < 0

    or product_revenue_usd < 0

    or conversion_gap_to_category < 0

    or modeled_additional_orders_full_gap < 0

    or modeled_revenue_opportunity_full_gap_usd < 0