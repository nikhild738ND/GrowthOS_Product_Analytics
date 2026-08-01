{{ config(
    materialized = 'view',
    tags = ['intermediate', 'funnel']
) }}

with funnel_events as (

    select
        session_id,
        event_name,
        event_timestamp

    from {{ ref('stg_ga4_events') }}

    where
        session_id is not null
        and event_name in (
            'view_item',
            'add_to_cart',
            'begin_checkout',
            'purchase'
        )
),

view_stage as (

    select
        session_id,
        min(event_timestamp) as sequential_view_item_at

    from funnel_events

    where event_name = 'view_item'

    group by session_id
),

cart_stage as (

    select
        view_stage.session_id,
        view_stage.sequential_view_item_at,

        min(funnel_events.event_timestamp)
            as sequential_add_to_cart_at

    from view_stage

    left join funnel_events
        on funnel_events.session_id = view_stage.session_id
        and funnel_events.event_name = 'add_to_cart'
        and funnel_events.event_timestamp
            >= view_stage.sequential_view_item_at

    group by
        view_stage.session_id,
        view_stage.sequential_view_item_at
),

checkout_stage as (

    select
        cart_stage.session_id,
        cart_stage.sequential_view_item_at,
        cart_stage.sequential_add_to_cart_at,

        min(funnel_events.event_timestamp)
            as sequential_begin_checkout_at

    from cart_stage

    left join funnel_events
        on funnel_events.session_id = cart_stage.session_id
        and funnel_events.event_name = 'begin_checkout'
        and cart_stage.sequential_add_to_cart_at is not null
        and funnel_events.event_timestamp
            >= cart_stage.sequential_add_to_cart_at

    group by
        cart_stage.session_id,
        cart_stage.sequential_view_item_at,
        cart_stage.sequential_add_to_cart_at
),

purchase_stage as (

    select
        checkout_stage.session_id,
        checkout_stage.sequential_view_item_at,
        checkout_stage.sequential_add_to_cart_at,
        checkout_stage.sequential_begin_checkout_at,

        min(funnel_events.event_timestamp)
            as sequential_purchase_at

    from checkout_stage

    left join funnel_events
        on funnel_events.session_id = checkout_stage.session_id
        and funnel_events.event_name = 'purchase'
        and checkout_stage.sequential_begin_checkout_at is not null
        and funnel_events.event_timestamp
            >= checkout_stage.sequential_begin_checkout_at

    group by
        checkout_stage.session_id,
        checkout_stage.sequential_view_item_at,
        checkout_stage.sequential_add_to_cart_at,
        checkout_stage.sequential_begin_checkout_at
)

select
    sessions.*,

    purchase_stage.sequential_view_item_at,
    purchase_stage.sequential_add_to_cart_at,
    purchase_stage.sequential_begin_checkout_at,
    purchase_stage.sequential_purchase_at,

    purchase_stage.sequential_view_item_at is not null
        as sequential_viewed_item,

    purchase_stage.sequential_add_to_cart_at is not null
        as sequential_added_to_cart,

    purchase_stage.sequential_begin_checkout_at is not null
        as sequential_began_checkout,

    purchase_stage.sequential_purchase_at is not null
        as sequential_purchased,

    sessions.viewed_item
        and sessions.added_to_cart
        and sessions.began_checkout
        and sessions.purchased
        as observed_complete_funnel,

    purchase_stage.sequential_purchase_at is not null
        as completed_sequential_funnel,

    (
        sessions.added_to_cart
        and purchase_stage.sequential_add_to_cart_at is null
    )
    or (
        sessions.began_checkout
        and purchase_stage.sequential_begin_checkout_at is null
    )
    or (
        sessions.purchased
        and purchase_stage.sequential_purchase_at is null
    )
        as has_funnel_order_gap,

    sessions.purchased
        and purchase_stage.sequential_purchase_at is null
        as purchased_without_ordered_funnel,

    coalesce(
        purchase_stage.sequential_add_to_cart_at
            = purchase_stage.sequential_view_item_at
        or purchase_stage.sequential_begin_checkout_at
            = purchase_stage.sequential_add_to_cart_at
        or purchase_stage.sequential_purchase_at
            = purchase_stage.sequential_begin_checkout_at,
        false
    ) as has_same_timestamp_transition,

    case
        when purchase_stage.sequential_add_to_cart_at is not null
        then timestamp_diff(
            purchase_stage.sequential_add_to_cart_at,
            purchase_stage.sequential_view_item_at,
            second
        )
    end as seconds_view_to_cart,

    case
        when purchase_stage.sequential_begin_checkout_at is not null
        then timestamp_diff(
            purchase_stage.sequential_begin_checkout_at,
            purchase_stage.sequential_add_to_cart_at,
            second
        )
    end as seconds_cart_to_checkout,

    case
        when purchase_stage.sequential_purchase_at is not null
        then timestamp_diff(
            purchase_stage.sequential_purchase_at,
            purchase_stage.sequential_begin_checkout_at,
            second
        )
    end as seconds_checkout_to_purchase,

    case
        when purchase_stage.sequential_purchase_at is not null
        then timestamp_diff(
            purchase_stage.sequential_purchase_at,
            purchase_stage.sequential_view_item_at,
            second
        )
    end as seconds_view_to_purchase,

    case
        when purchase_stage.sequential_purchase_at is not null then 4
        when purchase_stage.sequential_begin_checkout_at is not null then 3
        when purchase_stage.sequential_add_to_cart_at is not null then 2
        when purchase_stage.sequential_view_item_at is not null then 1
        else 0
    end as deepest_sequential_stage_number,

    case
        when purchase_stage.sequential_purchase_at is not null
            then '4 - Purchase'
        when purchase_stage.sequential_begin_checkout_at is not null
            then '3 - Checkout'
        when purchase_stage.sequential_add_to_cart_at is not null
            then '2 - Add to cart'
        when purchase_stage.sequential_view_item_at is not null
            then '1 - Product view'
        else '0 - No product view'
    end as deepest_sequential_stage,

    case
        when purchase_stage.sequential_purchase_at is not null
            then 'Converted'
        when purchase_stage.sequential_begin_checkout_at is not null
            then 'Dropped after checkout'
        when purchase_stage.sequential_add_to_cart_at is not null
            then 'Dropped after cart'
        when purchase_stage.sequential_view_item_at is not null
            then 'Dropped after product view'
        else 'No product view'
    end as funnel_status

from {{ ref('int_sessions') }} as sessions

left join purchase_stage
    using (session_id)