{{ config(materialized='view') }}

select
    parse_date('%Y%m%d', event_date) as event_date,
    timestamp_micros(event_timestamp) as event_timestamp,
    event_name,
    user_pseudo_id
from
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
where
    _table_suffix between '20201101' and '20210131'