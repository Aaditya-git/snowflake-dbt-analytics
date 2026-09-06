-- Silver, stage 1 of 2 for order headers: parse the JSON payload into typed columns,
-- deduplicate source replays, conform the enumerations, and label the rows that
-- cannot be trusted.

{{ config(materialized = 'ephemeral') }}

with bronze as (

    select * from {{ ref('bronze_orders') }}

),

customers as (

    select customer_id from {{ ref('silver_customers') }}

),

deduplicated as (

    -- The source replays orders on retry. Keeping the latest version by order_ts
    -- means a corrected order supersedes the original rather than double-counting
    -- into revenue, which is the single most expensive defect this pipeline can ship.
    select *
    from (
        select
            bronze.*,
            row_number() over (
                partition by order_id
                order by order_ts desc, _loaded_at desc
            ) as _version_rank
        from bronze
    )
    where _version_rank = 1

),

parsed as (

    select
        deduplicated.order_id,
        deduplicated.customer_id,
        deduplicated.order_ts,
        deduplicated.order_ts::date                     as order_date,

        lower(trim(payload:channel::string))            as raw_channel,
        lower(trim(payload:device::string))             as order_device,
        coalesce(payload:promo:applied::boolean, false) as raw_promo_applied,
        nullif(trim(payload:promo:code::string), '')    as promo_code,

        -- Kept so a downstream test can prove the FLATTEN did not silently lose a
        -- line: the count here must equal the rows silver_order_items produced.
        coalesce(array_size(payload:items), 0)          as payload_item_count,
        payload,

        deduplicated._record_hash,
        deduplicated._loaded_at,
        deduplicated._batch_id
    from deduplicated

),

conformed as (

    select
        parsed.*,
        -- Conform, do not reject: an unrecognised channel is a new sales surface
        -- nobody told the data team about. Bucketing it as 'other' keeps the order's
        -- revenue in the totals while still making the gap visible in a GROUP BY.
        case
            when raw_channel in ('web', 'app', 'store') then raw_channel
            else 'other'
        end as order_channel,
        -- Repair: 'promo applied' with no promo code is a source bug, and trusting
        -- the flag would overstate discount attribution. The code is the evidence.
        (raw_promo_applied and promo_code is not null) as promo_applied
    from parsed

)

select
    conformed.*,
    case
        when conformed.order_id is null   then 'missing_order_id'
        when conformed.order_ts is null   then 'unparseable_order_ts'
        -- payload is null only when try_parse_json rejected the document upstream.
        when conformed.payload is null    then 'malformed_json_payload'
        when conformed.order_date > dateadd(
                day, {{ var('future_order_tolerance_days') }}, current_date()
             )                            then 'future_dated_order'
        when customers.customer_id is null then 'unknown_customer'
    end as dq_failure_reason
from conformed
left join customers on conformed.customer_id = customers.customer_id
