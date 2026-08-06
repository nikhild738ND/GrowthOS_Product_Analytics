select
    session_id,
    sequential_view_item_at,
    sequential_add_to_cart_at,
    sequential_begin_checkout_at,
    sequential_purchase_at,
    seconds_view_to_cart,
    seconds_cart_to_checkout,
    seconds_checkout_to_purchase,
    seconds_view_to_purchase

from {{ ref('int_session_funnel') }}

where
    (
        sequential_add_to_cart_at is not null
        and (
            sequential_view_item_at is null
            or sequential_add_to_cart_at
                < sequential_view_item_at
        )
    )
    or (
        sequential_begin_checkout_at is not null
        and (
            sequential_add_to_cart_at is null
            or sequential_begin_checkout_at
                < sequential_add_to_cart_at
        )
    )
    or (
        sequential_purchase_at is not null
        and (
            sequential_begin_checkout_at is null
            or sequential_purchase_at
                < sequential_begin_checkout_at
        )
    )
    or seconds_view_to_cart < 0
    or seconds_cart_to_checkout < 0
    or seconds_checkout_to_purchase < 0
    or seconds_view_to_purchase < 0