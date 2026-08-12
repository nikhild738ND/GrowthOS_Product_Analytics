{{ config(
    materialized = 'table',
    tags = ['mart', 'tableau', 'funnel']
) }}

with daily_counts as (

    select
        session_date as metric_date,

        countif(
            viewed_item
        ) as observed_view_sessions,

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
        ) as sequential_view_sessions,

        countif(
            sequential_added_to_cart
        ) as sequential_cart_sessions,

        countif(
            sequential_began_checkout
        ) as sequential_checkout_sessions,

        countif(
            sequential_purchased
        ) as sequential_purchase_sessions

    from {{ ref('int_session_funnel') }}

    group by
        metric_date
),

stage_rows as (

    select
        metric_date,
        'Observed' as funnel_type,
        1 as stage_number,
        'Product view' as stage_name,
        '1 - Product view' as stage_label,
        observed_view_sessions as stage_sessions

    from daily_counts

    union all

    select
        metric_date,
        'Observed',
        2,
        'Add to cart',
        '2 - Add to cart',
        observed_cart_sessions

    from daily_counts

    union all

    select
        metric_date,
        'Observed',
        3,
        'Checkout',
        '3 - Checkout',
        observed_checkout_sessions

    from daily_counts

    union all

    select
        metric_date,
        'Observed',
        4,
        'Purchase',
        '4 - Purchase',
        observed_purchase_sessions

    from daily_counts

    union all

    select
        metric_date,
        'Sequential',
        1,
        'Product view',
        '1 - Product view',
        sequential_view_sessions

    from daily_counts

    union all

    select
        metric_date,
        'Sequential',
        2,
        'Add to cart',
        '2 - Add to cart',
        sequential_cart_sessions

    from daily_counts

    union all

    select
        metric_date,
        'Sequential',
        3,
        'Checkout',
        '3 - Checkout',
        sequential_checkout_sessions

    from daily_counts

    union all

    select
        metric_date,
        'Sequential',
        4,
        'Purchase',
        '4 - Purchase',
        sequential_purchase_sessions

    from daily_counts
),

with_comparisons as (

    select
        *,

        lag(
            stage_sessions
        ) over (
            partition by
                metric_date,
                funnel_type

            order by
                stage_number
        ) as previous_stage_sessions,

        first_value(
            stage_sessions
        ) over (
            partition by
                metric_date,
                funnel_type

            order by
                stage_number

            rows between
                unbounded preceding
                and unbounded following
        ) as stage_1_sessions

    from stage_rows
)

select
    concat(
        format_date(
            '%Y%m%d',
            metric_date
        ),
        '|',
        lower(funnel_type),
        '|',
        cast(stage_number as string)
    ) as funnel_daily_id,

    metric_date,
    funnel_type,
    stage_number,
    stage_name,
    stage_label,

    stage_sessions,
    previous_stage_sessions,
    stage_1_sessions,

    case
        when stage_number = 1 then 1.0

        else safe_divide(
            stage_sessions,
            previous_stage_sessions
        )
    end as stage_conversion_rate,

    safe_divide(
        stage_sessions,
        stage_1_sessions
    ) as stage_1_retention_rate,

    case
        when stage_number = 1 then 0

        when stage_sessions <= previous_stage_sessions
        then previous_stage_sessions - stage_sessions
    end as dropoff_sessions,

    case
        when stage_number = 1 then 0.0

        when stage_sessions <= previous_stage_sessions
        then safe_divide(
            previous_stage_sessions - stage_sessions,
            previous_stage_sessions
        )
    end as dropoff_rate,

    case
        when stage_number = 1 then false

        else stage_sessions > previous_stage_sessions
    end as has_stage_increase

from with_comparisons