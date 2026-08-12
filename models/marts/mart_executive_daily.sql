{{ config(
    materialized = 'table',
    tags = ['mart', 'tableau', 'executive']
) }}

with session_daily as (

    select
        session_date as metric_date,

        count(*) as total_sessions,

        count(
            distinct user_pseudo_id
        ) as daily_active_users,

        countif(
            is_new_user_session
        ) as new_user_sessions,

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

        sum(
            event_count
        ) as total_events,

        sum(
            page_view_count
        ) as total_page_views,

        avg(
            session_duration_seconds
        ) as average_session_duration_seconds,

        avg(
            engagement_time_msec
        ) / 1000.0 as average_engagement_seconds

    from {{ ref('int_session_funnel') }}

    group by
        metric_date
),

order_daily as (

    select
        order_date as metric_date,

        count(*) as order_count,

        sum(
            order_revenue_usd
        ) as revenue_usd,

        sum(
            order_item_quantity
        ) as units_purchased

    from {{ ref('int_orders') }}

    group by
        metric_date
),

all_dates as (

    select metric_date
    from session_daily

    union distinct

    select metric_date
    from order_daily
)

select
    format_date(
        '%Y%m%d',
        dates.metric_date
    ) as executive_daily_id,

    dates.metric_date,

    date_trunc(
        dates.metric_date,
        week(monday)
    ) as week_start_date,

    date_trunc(
        dates.metric_date,
        month
    ) as month_start_date,

    format_date(
        '%A',
        dates.metric_date
    ) as day_name,

    coalesce(
        sessions.total_sessions,
        0
    ) as total_sessions,

    coalesce(
        sessions.daily_active_users,
        0
    ) as daily_active_users,

    coalesce(
        sessions.new_user_sessions,
        0
    ) as new_user_sessions,

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

    coalesce(
        sessions.total_events,
        0
    ) as total_events,

    coalesce(
        sessions.total_page_views,
        0
    ) as total_page_views,

    sessions.average_session_duration_seconds,
    sessions.average_engagement_seconds,

    coalesce(
        orders.order_count,
        0
    ) as order_count,

    coalesce(
        orders.revenue_usd,
        0.0
    ) as revenue_usd,

    coalesce(
        orders.units_purchased,
        0
    ) as units_purchased,

    safe_divide(
        sessions.observed_purchase_sessions,
        sessions.total_sessions
    ) as observed_session_conversion_rate,

    safe_divide(
        sessions.sequential_purchase_sessions,
        sessions.total_sessions
    ) as sequential_completion_rate,

    safe_divide(
        orders.revenue_usd,
        orders.order_count
    ) as average_order_value_usd,

    safe_divide(
        orders.revenue_usd,
        sessions.total_sessions
    ) as revenue_per_session_usd,

    safe_divide(
        sessions.total_events,
        sessions.total_sessions
    ) as events_per_session,

    safe_divide(
        sessions.total_page_views,
        sessions.total_sessions
    ) as page_views_per_session

from all_dates as dates

left join session_daily as sessions
    using (metric_date)

left join order_daily as orders
    using (metric_date)