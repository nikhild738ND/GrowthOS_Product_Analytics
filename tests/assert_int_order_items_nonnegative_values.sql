select
    order_item_id,
    transaction_id,
    quantity,
    item_price_usd,
    line_revenue_usd

from {{ ref('int_order_items') }}

where
    quantity < 0
    or item_price_usd < 0
    or line_revenue_usd < 0