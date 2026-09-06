-- Bronze: land the order feed incrementally.
--
-- Incremental because this is the only high-volume feed here, and a full refresh of
-- an order history is the kind of thing that quietly turns into a forty-minute job
-- once the table is real. The merge key is the record hash rather than order_id: the
-- source replays orders, and bronze keeps every version it was sent. Deduplication
-- is a silver concern, so `unique` on order_id is deliberately NOT tested here.
--
-- The hash also makes a replay idempotent -- rerunning the same file merges onto the
-- rows already present instead of appending a second copy.

{{ config(
    materialized = 'incremental',
    unique_key = '_record_hash',
    incremental_strategy = 'merge',
    on_schema_change = 'append_new_columns'
) }}

with source as (

    select * from {{ ref('raw_orders') }}

    {% if is_incremental() %}
    -- Only look at rows newer than the high-water mark already landed. The one-day
    -- lookback covers late-arriving records from a source that is not strictly
    -- ordered; the merge key makes reprocessing that overlap harmless.
    where try_to_timestamp_ntz(order_ts) >= (
        select dateadd(day, -1, coalesce(max(order_ts), to_timestamp_ntz('1900-01-01')))
        from {{ this }}
    )
    {% endif %}

),

typed as (

    select
        try_to_number(order_id)             as order_id,
        try_to_number(customer_id)          as customer_id,
        try_to_timestamp_ntz(order_ts)      as order_ts,
        payload                             as payload_text,
        -- try_parse_json returns null on malformed JSON instead of failing the run,
        -- which is what lets a single bad event be quarantined rather than fatal.
        try_parse_json(payload)             as payload
    from source

)

select
    typed.*,
    {{ audit_columns(['order_id', 'order_ts', 'payload_text']) }}
from typed
