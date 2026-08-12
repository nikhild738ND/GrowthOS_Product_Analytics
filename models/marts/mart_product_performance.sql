{{ config(
    materialized = 'table',
    tags = ['mart', 'tableau', 'product']
) }}

with item_activity as (

    select
        event_date as metric_date,

        case
            when item_id is not null
            then concat(
                'id:',
                item_id
            )

            else concat(
                'name:',
                coalesce(
                    item_name,
                    'unknown'
                ),
                '|variant:',
                coalesce(
                    item_variant,
                    'unknown'
                )
            )
        end as product_key,

        event_timestamp,
        event_name,
        session_id,

        item_id,
        item_name,
        item_brand,
        item_variant,
        item_category

    from {{ ref('stg_ga4_items') }}

    where event_name in (
        'view_item',
        'add_to_cart',
        'purchase'
    )
),

event_daily as (

    select
        metric_date,
        product_key,

        (
            array_agg(
                item_id ignore nulls
                order by event_timestamp desc
                limit 1
            )
        )[safe_offset(0)] as item_id,

        (
            array_agg(
                item_name ignore nulls
                order by event_timestamp desc
                limit 1
            )
        )[safe_offset(0)] as item_name,

        (
            array_agg(
                item_brand ignore nulls
                order by event_timestamp desc
                limit 1
            )
        )[safe_offset(0)] as item_brand,

        (
            array_agg(
                item_variant ignore nulls
                order by event_timestamp desc
                limit 1
            )
        )[safe_offset(0)] as item_variant,

        (
            array_agg(
                item_category ignore nulls
                order by event_timestamp desc
                limit 1
            )
        )[safe_offset(0)] as item_category,

        countif(
            event_name = 'view_item'
        ) as view_item_events,

        count(
            distinct if(
                event_name = 'view_item',
                session_id,
                null
            )
        ) as view_item_sessions,

        countif(
            event_name = 'add_to_cart'
        ) as add_to_cart_events,

        count(
            distinct if(
                event_name = 'add_to_cart',
                session_id,
                null
            )
        ) as add_to_cart_sessions,

        countif(
            event_name = 'purchase'
        ) as raw_purchase_item_rows

    from item_activity

    group by
        metric_date,
        product_key
),

order_daily as (

    select
        order_date as metric_date,
        product_key,

        (
            array_agg(
                item_id ignore nulls
                order by purchased_at desc
                limit 1
            )
        )[safe_offset(0)] as item_id,

        (
            array_agg(
                item_name ignore nulls
                order by purchased_at desc
                limit 1
            )
        )[safe_offset(0)] as item_name,

        (
            array_agg(
                item_brand ignore nulls
                order by purchased_at desc
                limit 1
            )
        )[safe_offset(0)] as item_brand,

        (
            array_agg(
                item_variant ignore nulls
                order by purchased_at desc
                limit 1
            )
        )[safe_offset(0)] as item_variant,

        (
            array_agg(
                item_category ignore nulls
                order by purchased_at desc
                limit 1
            )
        )[safe_offset(0)] as item_category,

        count(
            distinct transaction_id
        ) as order_count,

        sum(
            quantity
        ) as units_purchased,

        sum(
            line_revenue_usd
        ) as product_revenue_usd

    from {{ ref('int_order_items') }}

    group by
        metric_date,
        product_key
),

all_product_keys as (

    select
        metric_date,
        product_key

    from event_daily

    union distinct

    select
        metric_date,
        product_key

    from order_daily
),

combined as (

    select
        product_keys.metric_date,
        product_keys.product_key,

        coalesce(
            events.item_id,
            orders.item_id
        ) as item_id,

        coalesce(
            events.item_name,
            orders.item_name
        ) as item_name,

        coalesce(
            events.item_brand,
            orders.item_brand
        ) as item_brand,

        coalesce(
            events.item_variant,
            orders.item_variant
        ) as item_variant,

        coalesce(
            events.item_category,
            orders.item_category
        ) as item_category,

        coalesce(
            events.view_item_events,
            0
        ) as view_item_events,

        coalesce(
            events.view_item_sessions,
            0
        ) as view_item_sessions,

        coalesce(
            events.add_to_cart_events,
            0
        ) as add_to_cart_events,

        coalesce(
            events.add_to_cart_sessions,
            0
        ) as add_to_cart_sessions,

        coalesce(
            events.raw_purchase_item_rows,
            0
        ) as raw_purchase_item_rows,

        coalesce(
            orders.order_count,
            0
        ) as order_count,

        coalesce(
            orders.units_purchased,
            0
        ) as units_purchased,

        coalesce(
            orders.product_revenue_usd,
            0.0
        ) as product_revenue_usd

    from all_product_keys as product_keys

    left join event_daily as events
        using (
            metric_date,
            product_key
        )

    left join order_daily as orders
        using (
            metric_date,
            product_key
        )
)

select
    to_hex(
        md5(
            concat(
                cast(metric_date as string),
                '|',
                product_key
            )
        )
    ) as product_daily_id,

    *,

    safe_divide(
        add_to_cart_sessions,
        view_item_sessions
    ) as same_day_view_to_cart_rate,

    safe_divide(
        order_count,
        view_item_sessions
    ) as same_day_view_session_to_order_rate,

    safe_divide(
        order_count,
        add_to_cart_sessions
    ) as same_day_cart_session_to_order_rate,

    safe_divide(
        product_revenue_usd,
        units_purchased
    ) as average_unit_revenue_usd,

    coalesce(
        safe_divide(
            order_count,
            view_item_sessions
        ) > 1,
        false
    ) as same_day_order_rate_over_one

from combined