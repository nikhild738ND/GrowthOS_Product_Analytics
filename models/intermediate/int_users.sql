{{ config(
    materialized = 'view',
    tags = ['intermediate', 'users']
) }}

with session_rollup as (

    select
        user_pseudo_id,

        min(session_date) as first_seen_date,
        max(session_date) as last_seen_date,

        min(session_start_at) as first_session_at,
        max(session_end_at) as last_session_at,

        count(*) as session_count,

        countif(viewed_item) as product_view_session_count,
        countif(added_to_cart) as cart_session_count,
        countif(began_checkout) as checkout_session_count,
        countif(purchased) as purchase_session_count,

        sum(event_count) as total_events,
        sum(page_view_count) as total_page_views,

        sum(
            coalesce(engagement_time_msec, 0)
        ) / 1000.0 as total_engagement_seconds,

        (
            array_agg(
                coalesce(device_category, 'Unknown')
                order by session_start_at
                limit 1
            )
        )[safe_offset(0)] as first_device_category,

        (
            array_agg(
                coalesce(country, 'Unknown')
                order by session_start_at
                limit 1
            )
        )[safe_offset(0)] as first_country,

        (
            array_agg(
                coalesce(first_user_source, 'Unknown')
                order by session_start_at
                limit 1
            )
        )[safe_offset(0)] as first_user_source,

        (
            array_agg(
                coalesce(first_user_medium, 'Unknown')
                order by session_start_at
                limit 1
            )
        )[safe_offset(0)] as first_user_medium

    from {{ ref('int_sessions') }}

    where user_pseudo_id is not null

    group by user_pseudo_id
),

order_rollup as (

    select
        user_pseudo_id,

        min(order_date) as first_purchase_date,
        max(order_date) as last_purchase_date,

        min(purchased_at) as first_purchase_at,
        max(purchased_at) as last_purchase_at,

        count(*) as order_count,

        sum(order_revenue_usd) as lifetime_revenue_usd,

        sum(order_item_quantity) as units_purchased

    from {{ ref('int_orders') }}

    where user_pseudo_id is not null

    group by user_pseudo_id
),

data_window as (

    select
        max(session_date) as dataset_end_date

    from {{ ref('int_sessions') }}
)

select
    to_hex(
        md5(sessions.user_pseudo_id)
    ) as anonymous_user_key,

    sessions.user_pseudo_id,

    sessions.first_seen_date,
    sessions.last_seen_date,

    sessions.first_session_at,
    sessions.last_session_at,

    data_window.dataset_end_date,

    sessions.first_device_category,
    sessions.first_country,
    sessions.first_user_source,
    sessions.first_user_medium,

    sessions.session_count,
    sessions.product_view_session_count,
    sessions.cart_session_count,
    sessions.checkout_session_count,
    sessions.purchase_session_count,

    sessions.total_events,
    sessions.total_page_views,
    sessions.total_engagement_seconds,

    orders.first_purchase_date,
    orders.last_purchase_date,

    orders.first_purchase_at,
    orders.last_purchase_at,

    coalesce(
        orders.order_count,
        0
    ) as order_count,

    coalesce(
        orders.lifetime_revenue_usd,
        0.0
    ) as lifetime_revenue_usd,

    coalesce(
        orders.units_purchased,
        0
    ) as units_purchased,

    safe_divide(
        orders.lifetime_revenue_usd,
        orders.order_count
    ) as average_order_value_usd,

    date_diff(
        sessions.last_seen_date,
        sessions.first_seen_date,
        day
    ) + 1 as observed_user_span_days,

    date_diff(
        data_window.dataset_end_date,
        sessions.last_seen_date,
        day
    ) as recency_days_at_dataset_end,

    case
        when orders.first_purchase_date >= sessions.first_seen_date
        then date_diff(
            orders.first_purchase_date,
            sessions.first_seen_date,
            day
        )
    end as days_to_first_purchase,

    coalesce(
        orders.first_purchase_date < sessions.first_seen_date,
        false
    ) as has_purchase_before_first_session,

    coalesce(
        orders.order_count,
        0
    ) > 0 as has_purchased,

    coalesce(
        orders.order_count,
        0
    ) >= 2 as is_repeat_purchaser,

    case
        when coalesce(orders.order_count, 0) >= 2
            then 'Repeat purchaser'

        when coalesce(orders.order_count, 0) = 1
            then 'One-time purchaser'

        else 'Non-purchaser'
    end as customer_status

from session_rollup as sessions

left join order_rollup as orders
    using (user_pseudo_id)

cross join data_window