-- Order headers: parse the semi-structured JSON payload (VARIANT) into typed columns.
with source as (

    select * from {{ ref('raw_orders') }}

),

parsed as (

    select
        order_id,
        customer_id,
        order_ts::timestamp_ntz as order_ts,
        try_parse_json(payload)  as payload
    from source

)

select
    order_id,
    customer_id,
    order_ts,
    order_ts::date                       as order_date,
    payload:channel::string              as order_channel,
    payload:device::string               as order_device,
    coalesce(payload:promo:applied::boolean, false) as promo_applied,
    payload:promo:code::string           as promo_code
from parsed
