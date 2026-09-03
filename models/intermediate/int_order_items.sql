{{ config(
    materialized = 'view',
    tags = ['intermediate', 'orders', 'items']
) }}

with purchase_item_events as (

    select *

    from {{ ref('stg_ga4_items') }}

    where
        event_name = 'purchase'
        and transaction_id is not null
),

distinct_purchase_events as (

    select distinct
        transaction_id,
        event_key,
        event_timestamp

    from purchase_item_events
),

ranked_purchase_events as (

    select
        transaction_id,
        event_key,
        event_timestamp,

        row_number() over (
            partition by transaction_id
            order by
                event_timestamp,
                event_key
        ) as purchase_event_rank

    from distinct_purchase_events
),

canonical_purchase_events as (

    select
        transaction_id,
        event_key

    from ranked_purchase_events

    where purchase_event_rank = 1
),

canonical_items as (

    select
        items.*

    from purchase_item_events as items

    inner join canonical_purchase_events as canonical
        on items.transaction_id = canonical.transaction_id
        and items.event_key = canonical.event_key
)

select
    to_hex(
        md5(
            concat(
                items.transaction_id,
                '|',
                items.event_key,
                '|',
                cast(items.item_position as string)
            )
        )
    ) as order_item_id,

    items.transaction_id,
    items.event_key as purchase_event_key,

    orders.order_date,
    orders.purchased_at,
    orders.session_id,
    orders.user_pseudo_id,

    items.item_position,

    case
        when items.item_id is not null
        then concat(
            'id:',
            items.item_id
        )

        else concat(
            'name:',
            coalesce(items.item_name, 'unknown'),
            '|variant:',
            coalesce(items.item_variant, 'unknown')
        )
    end as product_key,

    items.item_id,
    items.item_name,
    items.item_brand,
    items.item_variant,

    items.item_category,
    items.item_category2,
    items.item_category3,
    items.item_category4,
    items.item_category5,

    items.quantity,
    items.item_price_usd,
    items.item_price_local,

    items.item_revenue_in_usd,
    items.item_revenue_local,

    coalesce(
        items.item_value_usd,
        0.0
    ) as line_revenue_usd,

    items.item_revenue_in_usd is null
        and items.item_price_usd is not null
        as used_calculated_line_value,

    items.item_value_usd is null
        as has_missing_line_value,

    items.coupon,
    items.affiliation,
    items.location_id,

    items.item_list_id,
    items.item_list_name,
    items.item_list_index,

    items.promotion_id,
    items.promotion_name,
    items.creative_name,
    items.creative_slot

from canonical_items as items

inner join {{ ref('int_orders') }} as orders
    using (transaction_id)