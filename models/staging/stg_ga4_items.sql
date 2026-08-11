{{ config(
    materialized = 'view',
    tags = ['staging', 'ga4', 'items']
) }}

with source as (

    select
        raw_event.event_date as event_date_raw,
        raw_event.event_timestamp as event_timestamp_micros,
        raw_event.event_previous_timestamp
            as event_previous_timestamp_micros,
        raw_event.event_bundle_sequence_id,
        raw_event.event_server_timestamp_offset,

        raw_event.event_name,
        raw_event.user_pseudo_id,
        raw_event.user_id,
        raw_event.platform,

        (
            select any_value(event_parameter.value.int_value)
            from unnest(raw_event.event_params) as event_parameter
            where event_parameter.key = 'ga_session_id'
        ) as ga_session_id,

        raw_event.ecommerce.transaction_id,
        raw_event.ecommerce.purchase_revenue_in_usd,
        raw_event.ecommerce.total_item_quantity,

        item_offset + 1 as item_position,

        item.item_id,
        item.item_name,
        item.item_brand,
        item.item_variant,

        item.item_category,
        item.item_category2,
        item.item_category3,
        item.item_category4,
        item.item_category5,

        item.price_in_usd as item_price_usd,
        item.price as item_price_local,
        item.quantity,

        item.item_revenue_in_usd,
        item.item_revenue as item_revenue_local,

        item.coupon,
        item.affiliation,
        item.location_id,

        item.item_list_id,
        item.item_list_name,
        item.item_list_index,

        item.promotion_id,
        item.promotion_name,
        item.creative_name,
        item.creative_slot

    from
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
            as raw_event

    cross join
        unnest(raw_event.items) as item
        with offset as item_offset

    where
        _table_suffix between '20201101' and '20210131'
),

normalized as (

    select
        parse_date(
            '%Y%m%d',
            event_date_raw
        ) as event_date,

        timestamp_micros(
            event_timestamp_micros
        ) as event_timestamp,

        event_name,
        user_pseudo_id,
        user_id,
        platform,
        ga_session_id,

        case
            when user_pseudo_id is not null
                and ga_session_id is not null
            then concat(
                user_pseudo_id,
                '-',
                cast(ga_session_id as string)
            )
        end as session_id,

        to_hex(
            md5(
                concat(
                    coalesce(user_pseudo_id, '<null-user>'),
                    '|',
                    cast(event_timestamp_micros as string),
                    '|',
                    coalesce(event_name, '<null-event>'),
                    '|',
                    cast(
                        coalesce(event_bundle_sequence_id, -1)
                        as string
                    ),
                    '|',
                    cast(
                        coalesce(
                            event_previous_timestamp_micros,
                            -1
                        )
                        as string
                    ),
                    '|',
                    cast(
                        coalesce(
                            event_server_timestamp_offset,
                            -1
                        )
                        as string
                    ),
                    '|',
                    coalesce(
                        transaction_id,
                        '<no-transaction>'
                    )
                )
            )
        ) as event_key,

        nullif(
            trim(transaction_id),
            ''
        ) as transaction_id,

        purchase_revenue_in_usd,
        total_item_quantity,

        item_position,

        nullif(trim(item_id), '') as item_id,
        nullif(trim(item_name), '') as item_name,
        nullif(trim(item_brand), '') as item_brand,
        nullif(trim(item_variant), '') as item_variant,

        nullif(trim(item_category), '') as item_category,
        nullif(trim(item_category2), '') as item_category2,
        nullif(trim(item_category3), '') as item_category3,
        nullif(trim(item_category4), '') as item_category4,
        nullif(trim(item_category5), '') as item_category5,

        item_price_usd,
        item_price_local,

        coalesce(
            quantity,
            1
        ) as quantity,

        item_revenue_in_usd,
        item_revenue_local,

        nullif(trim(coupon), '') as coupon,
        nullif(trim(affiliation), '') as affiliation,
        nullif(trim(location_id), '') as location_id,

        nullif(trim(item_list_id), '') as item_list_id,
        nullif(trim(item_list_name), '') as item_list_name,
        nullif(trim(item_list_index), '') as item_list_index,

        nullif(trim(promotion_id), '') as promotion_id,
        nullif(trim(promotion_name), '') as promotion_name,
        nullif(trim(creative_name), '') as creative_name,
        nullif(trim(creative_slot), '') as creative_slot

    from source
)

select
    to_hex(
        md5(
            concat(
                event_key,
                '|',
                cast(item_position as string)
            )
        )
    ) as event_item_id,

    normalized.*,

    coalesce(
        item_revenue_in_usd,
        item_price_usd * quantity
    ) as item_value_usd

from normalized