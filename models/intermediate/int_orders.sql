{{ config(
    materialized = 'view',
    tags = ['intermediate', 'orders']
) }}

with purchase_events as (

    select
        transaction_id,
        session_id,
        user_pseudo_id,

        event_date,
        event_timestamp,

        device_category,
        operating_system,
        browser,

        country,
        region,

        first_user_source,
        first_user_medium,
        first_user_campaign,

        purchase_revenue_usd,
        total_item_quantity

    from {{ ref('stg_ga4_events') }}

    where
        event_name = 'purchase'
        and transaction_id is not null
),

order_rollup as (

    select
        transaction_id,

        array_agg(
            struct(
                event_date as event_date,
                event_timestamp as event_timestamp,
                session_id as session_id,
                user_pseudo_id as user_pseudo_id,

                device_category as device_category,
                operating_system as operating_system,
                browser as browser,

                country as country,
                region as region,

                first_user_source as first_user_source,
                first_user_medium as first_user_medium,
                first_user_campaign as first_user_campaign
            )
            order by event_timestamp
            limit 1
        )[offset(0)] as first_purchase_event,

        min(event_timestamp) as purchased_at,

        coalesce(
            max(purchase_revenue_usd),
            0.0
        ) as order_revenue_usd,

        coalesce(
            max(total_item_quantity),
            0
        ) as order_item_quantity,

        count(*) as source_purchase_event_count,

        count(
            distinct session_id
        ) as source_session_count,

        count(*) > 1
            as has_duplicate_purchase_event,

        count(
            distinct session_id
        ) > 1 as spans_multiple_sessions,

        countif(
            purchase_revenue_usd is not null
        ) = 0 as has_missing_order_revenue

    from purchase_events

    group by transaction_id
)

select
    transaction_id,

    first_purchase_event.event_date as order_date,
    purchased_at,

    first_purchase_event.session_id as session_id,
    first_purchase_event.user_pseudo_id as user_pseudo_id,

    first_purchase_event.device_category as device_category,
    first_purchase_event.operating_system as operating_system,
    first_purchase_event.browser as browser,

    first_purchase_event.country as country,
    first_purchase_event.region as region,

    first_purchase_event.first_user_source
        as first_user_source,

    first_purchase_event.first_user_medium
        as first_user_medium,

    first_purchase_event.first_user_campaign
        as first_user_campaign,

    order_revenue_usd,
    order_item_quantity,

    source_purchase_event_count,
    source_session_count,

    has_duplicate_purchase_event,
    spans_multiple_sessions,
    has_missing_order_revenue

from order_rollup