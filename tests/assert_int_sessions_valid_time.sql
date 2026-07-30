select
    session_id,
    session_start_at,
    session_end_at,
    session_duration_seconds

from {{ ref('int_sessions') }}

where
    session_end_at < session_start_at
    or session_duration_seconds < 0