{{ config(
    materialized = 'table',
    tags = ['mart', 'tableau', 'customer', 'cohort']
) }}

with weekly_activity as (

    select distinct
        user_pseudo_id,

        date_trunc(
            session_date,
            week(monday)
        ) as activity_week

    from {{ ref('int_sessions') }}

    where user_pseudo_id is not null
),

user_cohort_base as (

    select
        user_pseudo_id,
        min(activity_week) as cohort_week

    from weekly_activity

    group by user_pseudo_id
),

user_cohorts as (

    select
        cohorts.user_pseudo_id,
        cohorts.cohort_week,

        coalesce(
            users.first_device_category,
            'Unknown'
        ) as first_device_category,

        coalesce(
            users.first_user_source,
            'Unknown'
        ) as first_user_source,

        coalesce(
            users.first_user_medium,
            'Unknown'
        ) as first_user_medium

    from user_cohort_base as cohorts

    inner join {{ ref('int_users') }} as users
        using (user_pseudo_id)
),

cohort_sizes as (

    select
        cohort_week,
        first_device_category,
        first_user_source,
        first_user_medium,

        count(*) as cohort_size

    from user_cohorts

    group by
        cohort_week,
        first_device_category,
        first_user_source,
        first_user_medium
),

cohort_activity as (

    select
        cohorts.cohort_week,
        cohorts.first_device_category,
        cohorts.first_user_source,
        cohorts.first_user_medium,

        activity.activity_week,

        date_diff(
            activity.activity_week,
            cohorts.cohort_week,
            week(monday)
        ) as cohort_age_weeks,

        count(
            distinct activity.user_pseudo_id
        ) as active_users

    from user_cohorts as cohorts

    inner join weekly_activity as activity
        using (user_pseudo_id)

    group by
        cohorts.cohort_week,
        cohorts.first_device_category,
        cohorts.first_user_source,
        cohorts.first_user_medium,
        activity.activity_week,
        cohort_age_weeks
),

data_window as (

    select
        max(activity_week) as last_activity_week

    from weekly_activity
),

cohort_scaffold as (

    select
        sizes.cohort_week,
        sizes.first_device_category,
        sizes.first_user_source,
        sizes.first_user_medium,
        sizes.cohort_size,

        cohort_age_weeks,

        date_add(
            sizes.cohort_week,
            interval cohort_age_weeks week
        ) as activity_week,

        date_diff(
            data_window.last_activity_week,
            sizes.cohort_week,
            week(monday)
        ) as max_observable_age_weeks

    from cohort_sizes as sizes

    cross join data_window

    cross join unnest(
        generate_array(
            0,
            date_diff(
                data_window.last_activity_week,
                sizes.cohort_week,
                week(monday)
            )
        )
    ) as cohort_age_weeks
)

select
    to_hex(
        md5(
            concat(
                cast(scaffold.cohort_week as string),
                '|',
                scaffold.first_device_category,
                '|',
                scaffold.first_user_source,
                '|',
                scaffold.first_user_medium,
                '|',
                cast(scaffold.cohort_age_weeks as string)
            )
        )
    ) as customer_cohort_id,

    scaffold.cohort_week,

    format_date(
        '%Y-%m-%d',
        scaffold.cohort_week
    ) as cohort_week_label,

    scaffold.activity_week,
    scaffold.cohort_age_weeks,

    concat(
        'Week ',
        cast(scaffold.cohort_age_weeks as string)
    ) as cohort_age_label,

    scaffold.first_device_category,
    scaffold.first_user_source,
    scaffold.first_user_medium,

    scaffold.cohort_size,

    coalesce(
        activity.active_users,
        0
    ) as active_users,

    safe_divide(
        coalesce(activity.active_users, 0),
        scaffold.cohort_size
    ) as retention_rate,

    scaffold.max_observable_age_weeks

from cohort_scaffold as scaffold

left join cohort_activity as activity
    on scaffold.cohort_week = activity.cohort_week

    and scaffold.first_device_category
        = activity.first_device_category

    and scaffold.first_user_source
        = activity.first_user_source

    and scaffold.first_user_medium
        = activity.first_user_medium

    and scaffold.activity_week
        = activity.activity_week