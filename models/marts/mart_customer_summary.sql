{{ config(
    materialized = 'table',
    tags = ['mart', 'tableau', 'customer']
) }}

select
    anonymous_user_key,

    first_seen_date,
    last_seen_date,

    date_trunc(
        first_seen_date,
        week(monday)
    ) as first_seen_week,

    date_trunc(
        first_seen_date,
        month
    ) as first_seen_month,

    first_purchase_date,
    last_purchase_date,

    first_device_category,
    first_country,
    first_user_source,
    first_user_medium,

    session_count,
    product_view_session_count,
    cart_session_count,
    checkout_session_count,
    purchase_session_count,

    total_events,
    total_page_views,
    total_engagement_seconds,

    order_count,
    lifetime_revenue_usd,
    units_purchased,
    average_order_value_usd,

    observed_user_span_days,
    recency_days_at_dataset_end,
    days_to_first_purchase,

    has_purchase_before_first_session,
    has_purchased,
    is_repeat_purchaser,

    customer_status,

    case customer_status
        when 'Non-purchaser' then 1
        when 'One-time purchaser' then 2
        when 'Repeat purchaser' then 3
    end as customer_status_sort,

    case
        when session_count = 1
            then '1 session'

        when session_count between 2 and 3
            then '2–3 sessions'

        when session_count between 4 and 7
            then '4–7 sessions'

        else '8+ sessions'
    end as session_frequency_band

from {{ ref('int_users') }}