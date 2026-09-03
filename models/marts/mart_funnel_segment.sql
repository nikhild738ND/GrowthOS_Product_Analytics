{{ config(
    materialized = 'table',
    tags = ['mart', 'tableau', 'funnel', 'segment']
) }}

with session_base as (

    select
        session_date as metric_date,

        coalesce(
            nullif(
                trim(device_category),
                ''
            ),
            'Unknown'
        ) as device_category,

        case
            when is_new_user_session
                then 'New user session'

            else 'Returning or other session'
        end as user_type,

        coalesce(
            nullif(
                trim(country),
                ''
            ),
            'Unknown'
        ) as country,

        coalesce(
            nullif(
                trim(first_user_source),
                ''
            ),
            'Unknown'
        ) as first_user_source,

        coalesce(
            nullif(
                trim(first_user_medium),
                ''
            ),
            'Unknown'
        ) as first_user_medium,

        viewed_item,
        added_to_cart,
        began_checkout,
        purchased,

        sequential_viewed_item,
        sequential_added_to_cart,
        sequential_began_checkout,
        sequential_purchased,

        has_funnel_order_gap,

        session_duration_seconds,
        engagement_time_msec

    from {{ ref('int_session_funnel') }}
),

session_agg as (

    select
        metric_date,
        device_category,
        user_type,
        country,
        first_user_source,
        first_user_medium,

        count(*) as total_sessions,

        countif(
            viewed_item
        ) as observed_product_view_sessions,

        countif(
            added_to_cart
        ) as observed_cart_sessions,

        countif(
            began_checkout
        ) as observed_checkout_sessions,

        countif(
            purchased
        ) as observed_purchase_sessions,

        countif(
            sequential_viewed_item
        ) as sequential_product_view_sessions,

        countif(
            sequential_added_to_cart
        ) as sequential_cart_sessions,

        countif(
            sequential_began_checkout
        ) as sequential_checkout_sessions,

        countif(
            sequential_purchased
        ) as sequential_purchase_sessions,

        countif(
            has_funnel_order_gap
        ) as sessions_with_funnel_order_gap,

        avg(
            session_duration_seconds
        ) as average_session_duration_seconds,

        avg(
            engagement_time_msec
        ) / 1000.0 as average_engagement_seconds

    from session_base

    group by
        metric_date,
        device_category,
        user_type,
        country,
        first_user_source,
        first_user_medium
),

order_base as (

    select
        orders.order_date as metric_date,

        coalesce(
            nullif(
                trim(funnel.device_category),
                ''
            ),
            nullif(
                trim(orders.device_category),
                ''
            ),
            'Unknown'
        ) as device_category,

        case
            when funnel.session_id is null
                then 'Unknown'

            when funnel.is_new_user_session
                then 'New user session'

            else 'Returning or other session'
        end as user_type,

        coalesce(
            nullif(
                trim(funnel.country),
                ''
            ),
            nullif(
                trim(orders.country),
                ''
            ),
            'Unknown'
        ) as country,

        coalesce(
            nullif(
                trim(funnel.first_user_source),
                ''
            ),
            nullif(
                trim(orders.first_user_source),
                ''
            ),
            'Unknown'
        ) as first_user_source,

        coalesce(
            nullif(
                trim(funnel.first_user_medium),
                ''
            ),
            nullif(
                trim(orders.first_user_medium),
                ''
            ),
            'Unknown'
        ) as first_user_medium,

        orders.transaction_id,
        orders.order_revenue_usd

    from {{ ref('int_orders') }} as orders

    left join {{ ref('int_session_funnel') }} as funnel
        using (session_id)
),

order_agg as (

    select
        metric_date,
        device_category,
        user_type,
        country,
        first_user_source,
        first_user_medium,

        count(*) as order_count,

        sum(
            order_revenue_usd
        ) as revenue_usd

    from order_base

    group by
        metric_date,
        device_category,
        user_type,
        country,
        first_user_source,
        first_user_medium
),

all_segment_keys as (

    select
        metric_date,
        device_category,
        user_type,
        country,
        first_user_source,
        first_user_medium

    from session_agg

    union distinct

    select
        metric_date,
        device_category,
        user_type,
        country,
        first_user_source,
        first_user_medium

    from order_agg
),

combined as (

    select
        segment_keys.metric_date,
        segment_keys.device_category,
        segment_keys.user_type,
        segment_keys.country,
        segment_keys.first_user_source,
        segment_keys.first_user_medium,

        coalesce(
            sessions.total_sessions,
            0
        ) as total_sessions,

        coalesce(
            sessions.observed_product_view_sessions,
            0
        ) as observed_product_view_sessions,

        coalesce(
            sessions.observed_cart_sessions,
            0
        ) as observed_cart_sessions,

        coalesce(
            sessions.observed_checkout_sessions,
            0
        ) as observed_checkout_sessions,

        coalesce(
            sessions.observed_purchase_sessions,
            0
        ) as observed_purchase_sessions,

        coalesce(
            sessions.sequential_product_view_sessions,
            0
        ) as sequential_product_view_sessions,

        coalesce(
            sessions.sequential_cart_sessions,
            0
        ) as sequential_cart_sessions,

        coalesce(
            sessions.sequential_checkout_sessions,
            0
        ) as sequential_checkout_sessions,

        coalesce(
            sessions.sequential_purchase_sessions,
            0
        ) as sequential_purchase_sessions,

        coalesce(
            sessions.sessions_with_funnel_order_gap,
            0
        ) as sessions_with_funnel_order_gap,

        sessions.average_session_duration_seconds,
        sessions.average_engagement_seconds,

        coalesce(
            orders.order_count,
            0
        ) as order_count,

        coalesce(
            orders.revenue_usd,
            0.0
        ) as revenue_usd

    from all_segment_keys as segment_keys

    left join session_agg as sessions
        using (
            metric_date,
            device_category,
            user_type,
            country,
            first_user_source,
            first_user_medium
        )

    left join order_agg as orders
        using (
            metric_date,
            device_category,
            user_type,
            country,
            first_user_source,
            first_user_medium
        )
)

select
    to_hex(
        md5(
            concat(
                cast(metric_date as string),
                '|',
                device_category,
                '|',
                user_type,
                '|',
                country,
                '|',
                first_user_source,
                '|',
                first_user_medium
            )
        )
    ) as funnel_segment_id,

    *,

    safe_divide(
        observed_cart_sessions,
        observed_product_view_sessions
    ) as observed_view_to_cart_rate,

    safe_divide(
        observed_checkout_sessions,
        observed_cart_sessions
    ) as observed_cart_to_checkout_rate,

    safe_divide(
        observed_purchase_sessions,
        observed_checkout_sessions
    ) as observed_checkout_to_purchase_rate,

    safe_divide(
        observed_purchase_sessions,
        total_sessions
    ) as observed_session_conversion_rate,

    safe_divide(
        sequential_cart_sessions,
        sequential_product_view_sessions
    ) as sequential_view_to_cart_rate,

    safe_divide(
        sequential_checkout_sessions,
        sequential_cart_sessions
    ) as sequential_cart_to_checkout_rate,

    safe_divide(
        sequential_purchase_sessions,
        sequential_checkout_sessions
    ) as sequential_checkout_to_purchase_rate,

    safe_divide(
        sequential_purchase_sessions,
        total_sessions
    ) as sequential_completion_rate,

    safe_divide(
        revenue_usd,
        total_sessions
    ) as revenue_per_session_usd,

    safe_divide(
        revenue_usd,
        order_count
    ) as average_order_value_usd

from combined