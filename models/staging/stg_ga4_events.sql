{{ config(
    materialized = 'view',
    tags = ['staging', 'ga4']
) }}

with source as (

    select
        event_date as event_date_raw,
        event_timestamp as event_timestamp_micros,
        event_name,
        user_pseudo_id,
        user_id,
        platform,

        device.category as device_category,
        device.operating_system as operating_system,
        device.language as device_language,
        device.web_info.browser as browser,

        geo.country as country,
        geo.region as region,
        geo.city as city,

        traffic_source.source as first_user_source,
        traffic_source.medium as first_user_medium,
        traffic_source.name as first_user_campaign,

        ecommerce.transaction_id as transaction_id,
        ecommerce.purchase_revenue_in_usd as purchase_revenue_usd,
        ecommerce.total_item_quantity as total_item_quantity,

        (
            select any_value(event_parameter.value.int_value)
            from unnest(event_params) as event_parameter
            where event_parameter.key = 'ga_session_id'
        ) as ga_session_id,

        (
            select any_value(event_parameter.value.int_value)
            from unnest(event_params) as event_parameter
            where event_parameter.key = 'ga_session_number'
        ) as ga_session_number,

        (
            select any_value(event_parameter.value.int_value)
            from unnest(event_params) as event_parameter
            where event_parameter.key = 'engagement_time_msec'
        ) as engagement_time_msec,

        (
            select any_value(event_parameter.value.string_value)
            from unnest(event_params) as event_parameter
            where event_parameter.key = 'page_location'
        ) as page_location,

        (
            select any_value(event_parameter.value.string_value)
            from unnest(event_params) as event_parameter
            where event_parameter.key = 'page_title'
        ) as page_title,

        (
            select any_value(event_parameter.value.string_value)
            from unnest(event_params) as event_parameter
            where event_parameter.key = 'page_referrer'
        ) as page_referrer

    from
        `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

    where
        _table_suffix between '20201101' and '20210131'
)

select
    parse_date('%Y%m%d', event_date_raw) as event_date,
    timestamp_micros(event_timestamp_micros) as event_timestamp,

    event_name,
    user_pseudo_id,
    user_id,
    platform,

    ga_session_id,
    ga_session_number,

    case
        when user_pseudo_id is not null
            and ga_session_id is not null
        then concat(
            user_pseudo_id,
            '-',
            cast(ga_session_id as string)
        )
    end as session_id,

    nullif(trim(device_category), '') as device_category,
    nullif(trim(operating_system), '') as operating_system,
    nullif(trim(device_language), '') as device_language,
    nullif(trim(browser), '') as browser,

    nullif(trim(country), '') as country,
    nullif(trim(region), '') as region,
    nullif(trim(city), '') as city,

    nullif(trim(first_user_source), '') as first_user_source,
    nullif(trim(first_user_medium), '') as first_user_medium,
    nullif(trim(first_user_campaign), '') as first_user_campaign,

    engagement_time_msec,
    page_location,
    page_title,
    page_referrer,

    nullif(trim(transaction_id), '') as transaction_id,
    purchase_revenue_usd,
    total_item_quantity

from source