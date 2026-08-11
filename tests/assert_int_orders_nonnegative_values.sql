select
    transaction_id,
    order_revenue_usd,
    order_item_quantity

from {{ ref('int_orders') }}

where
    order_revenue_usd < 0
    or order_item_quantity < 0