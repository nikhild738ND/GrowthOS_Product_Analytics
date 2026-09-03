select
    anonymous_user_key,
    first_seen_date,
    last_seen_date,
    session_count,
    order_count,
    lifetime_revenue_usd,
    units_purchased,
    observed_user_span_days,
    recency_days_at_dataset_end

from {{ ref('int_users') }}

where
    last_seen_date < first_seen_date

    or session_count <= 0

    or order_count < 0

    or lifetime_revenue_usd < 0

    or units_purchased < 0

    or observed_user_span_days <= 0

    or recency_days_at_dataset_end < 0