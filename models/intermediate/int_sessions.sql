{{ config(
    materialized = 'view',
    tags = ['intermediate', 'sessions']
) }}

with events as (

    select *
    from {{ ref('stg_ga4_events') }}
    where session_id is not null
),

session_rollup as (

    select
        session_id,
        any_value(user_pseudo_id) as user_pseudo_id,

        min(event_date) as session_date,
        min(event_timestamp) as session_start_at,
        max(event_timestamp) as session_end_at,

        timestamp_diff(
            max(event_timestamp),
            min(event_timestamp),
            second
        ) as session_duration_seconds,

        (
            array_agg(
                device_category ignore nulls
                order by event_timestamp
                limit 1
            )
        )[safe_offset(0)] as device_category,

        (
            array_agg(
                operating_system ignore nulls
                order by event_timestamp
                limit 1
            )
        )[safe_offset(0)] as operating_system,

        (
            array_agg(
                browser ignore nulls
                order by event_timestamp
                limit 1
            )
        )[safe_offset(0)] as browser,

        (
            array_agg(
                country ignore nulls
                order by event_timestamp
                limit 1
            )
        )[safe_offset(0)] as country,

        (
            array_agg(
                region ignore nulls
                order by event_timestamp
                limit 1
            )
        )[safe_offset(0)] as region,

        (
            array_agg(
                first_user_source ignore nulls
                order by event_timestamp
                limit 1
            )
        )[safe_offset(0)] as first_user_source,

        (
            array_agg(
                first_user_medium ignore nulls
                order by event_timestamp
                limit 1
            )
        )[safe_offset(0)] as first_user_medium,

        count(*) as event_count,

        sum(
            coalesce(engagement_time_msec, 0)
        ) as engagement_time_msec,

        countif(event_name = 'page_view') as page_view_count,
        countif(event_name = 'view_item') as view_item_count,
        countif(event_name = 'add_to_cart') as add_to_cart_count,
        countif(event_name = 'begin_checkout') as begin_checkout_count,
        countif(event_name = 'purchase') as purchase_event_count,

        countif(event_name = 'first_visit') > 0
            as is_new_user_session,

        countif(event_name = 'view_item') > 0
            as viewed_item,

        countif(event_name = 'add_to_cart') > 0
            as added_to_cart,

        countif(event_name = 'begin_checkout') > 0
            as began_checkout,

        countif(event_name = 'purchase') > 0
            as purchased,

        min(
            if(
                event_name = 'view_item',
                event_timestamp,
                null
            )
        ) as first_view_item_at,

        min(
            if(
                event_name = 'add_to_cart',
                event_timestamp,
                null
            )
        ) as first_add_to_cart_at,

        min(
            if(
                event_name = 'begin_checkout',
                event_timestamp,
                null
            )
        ) as first_begin_checkout_at,

        min(
            if(
                event_name = 'purchase',
                event_timestamp,
                null
            )
        ) as first_purchase_at

    from events

    group by session_id
),

deduplicated_orders as (

    select
        session_id,
        transaction_id,

        max(
            coalesce(purchase_revenue_usd, 0)
        ) as transaction_revenue_usd

    from events

    where
        event_name = 'purchase'
        and transaction_id is not null

    group by
        session_id,
        transaction_id
),

order_rollup as (

    select
        session_id,
        count(*) as transactions,
        sum(transaction_revenue_usd) as revenue_usd

    from deduplicated_orders

    group by session_id
)

select
    sessions.*,

    coalesce(
        orders.transactions,
        0
    ) as transactions,

    coalesce(
        orders.revenue_usd,
        0
    ) as revenue_usd

from session_rollup as sessions

left join order_rollup as orders
    using (session_id)