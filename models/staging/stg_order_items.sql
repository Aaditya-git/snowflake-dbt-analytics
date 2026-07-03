-- Order line items: explode the JSON payload's items[] array via LATERAL FLATTEN,
-- producing one row per product per order.
with source as (

    select
        order_id,
        try_parse_json(payload) as payload
    from {{ ref('raw_orders') }}

)

select
    source.order_id,
    item.value:product_id::integer as product_id,
    item.value:qty::integer        as quantity
from source,
     lateral flatten(input => source.payload:items) as item
