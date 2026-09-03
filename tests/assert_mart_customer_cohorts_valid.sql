select
    customer_cohort_id,
    cohort_week,
    activity_week,
    cohort_age_weeks,
    cohort_size,
    active_users,
    retention_rate

from {{ ref('mart_customer_cohorts') }}

where
    cohort_age_weeks < 0

    or cohort_size <= 0

    or active_users < 0

    or active_users > cohort_size

    or retention_rate < 0

    or retention_rate > 1

    or (
        cohort_age_weeks = 0
        and active_users != cohort_size
    )

    or (
        cohort_age_weeks = 0
        and abs(retention_rate - 1.0) > 0.000001
    )