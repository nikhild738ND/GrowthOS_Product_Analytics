{{ config(
    materialized = 'table',
    tags = ['mart', 'tableau', 'product', 'opportunity']
) }}

with product_rollup as (

    select
        product_key,

        min(metric_date) as first_activity_date,
        max(metric_date) as last_activity_date,

        (
            array_agg(
                item_id ignore nulls
                order by metric_date desc
                limit 1
            )
        )[safe_offset(0)] as item_id,

        (
            array_agg(
                item_name ignore nulls
                order by metric_date desc
                limit 1
            )
        )[safe_offset(0)] as item_name,

        (
            array_agg(
                item_brand ignore nulls
                order by metric_date desc
                limit 1
            )
        )[safe_offset(0)] as item_brand,

        (
            array_agg(
                item_variant ignore nulls
                order by metric_date desc
                limit 1
            )
        )[safe_offset(0)] as item_variant,

        coalesce(
            (
                array_agg(
                    nullif(trim(item_category), '')
                    ignore nulls
                    order by metric_date desc
                    limit 1
                )
            )[safe_offset(0)],
            'Unknown'
        ) as item_category,

        sum(view_item_events) as view_item_events,
        sum(view_item_sessions) as view_item_sessions,

        sum(add_to_cart_events) as add_to_cart_events,
        sum(add_to_cart_sessions) as add_to_cart_sessions,

        sum(order_count) as order_count,
        sum(units_purchased) as units_purchased,

        sum(product_revenue_usd) as product_revenue_usd

    from {{ ref('mart_product_performance') }}

    group by product_key
),

category_rollup as (

    select
        item_category,

        sum(view_item_sessions) as category_view_item_sessions,
        sum(add_to_cart_sessions) as category_add_to_cart_sessions,
        sum(order_count) as category_order_count,
        sum(product_revenue_usd) as category_revenue_usd

    from product_rollup

    group by item_category
),

portfolio_rollup as (

    select
        sum(view_item_sessions) as portfolio_view_item_sessions,
        sum(order_count) as portfolio_order_count,
        sum(product_revenue_usd) as portfolio_revenue_usd

    from product_rollup
),

benchmarked as (

    select
        products.*,

        categories.category_view_item_sessions,
        categories.category_add_to_cart_sessions,
        categories.category_order_count,
        categories.category_revenue_usd,

        portfolio.portfolio_view_item_sessions,
        portfolio.portfolio_order_count,
        portfolio.portfolio_revenue_usd,

        safe_divide(
            products.add_to_cart_sessions,
            products.view_item_sessions
        ) as product_view_to_cart_rate,

        safe_divide(
            products.order_count,
            products.view_item_sessions
        ) as product_view_to_order_rate,

        safe_divide(
            categories.category_order_count,
            categories.category_view_item_sessions
        ) as category_view_to_order_rate,

        safe_divide(
            portfolio.portfolio_order_count,
            portfolio.portfolio_view_item_sessions
        ) as portfolio_view_to_order_rate,

        safe_divide(
            products.product_revenue_usd,
            products.order_count
        ) as product_average_order_value_usd,

        safe_divide(
            categories.category_revenue_usd,
            categories.category_order_count
        ) as category_average_order_value_usd,

        safe_divide(
            portfolio.portfolio_revenue_usd,
            portfolio.portfolio_order_count
        ) as portfolio_average_order_value_usd

    from product_rollup as products

    left join category_rollup as categories
        using (item_category)

    cross join portfolio_rollup as portfolio
),

opportunity as (

    select
        *,

        case
            when view_item_sessions = 0 then 0.0

            else greatest(
                coalesce(category_view_to_order_rate, 0)
                - coalesce(product_view_to_order_rate, 0),
                0
            )
        end as conversion_gap_to_category,

        coalesce(
            product_average_order_value_usd,
            category_average_order_value_usd,
            portfolio_average_order_value_usd,
            0.0
        ) as opportunity_order_value_usd,

        (
            view_item_sessions = 0
            and order_count > 0
        )
        or coalesce(
            product_view_to_order_rate > 1,
            false
        ) as has_tracking_anomaly

    from benchmarked
)

select
    to_hex(
        md5(product_key)
    ) as product_opportunity_id,

    product_key,

    first_activity_date,
    last_activity_date,

    item_id,
    item_name,
    item_brand,
    item_variant,
    item_category,

    view_item_events,
    view_item_sessions,

    add_to_cart_events,
    add_to_cart_sessions,

    order_count,
    units_purchased,
    product_revenue_usd,

    product_view_to_cart_rate,
    product_view_to_order_rate,

    category_view_item_sessions,
    category_add_to_cart_sessions,
    category_order_count,
    category_revenue_usd,
    category_view_to_order_rate,

    portfolio_view_to_order_rate,

    product_average_order_value_usd,
    category_average_order_value_usd,
    opportunity_order_value_usd,

    conversion_gap_to_category,

    conversion_gap_to_category
        * view_item_sessions
        as modeled_additional_orders_full_gap,

    conversion_gap_to_category
        * view_item_sessions
        * opportunity_order_value_usd
        as modeled_revenue_opportunity_full_gap_usd,

    has_tracking_anomaly,

    case
        when view_item_sessions = 0
            then 'No observed product views'

        when has_tracking_anomaly
            then 'Tracking review needed'

        when conversion_gap_to_category > 0
            then 'Experiment candidate'

        else 'At or above category benchmark'
    end as opportunity_status

from opportunity