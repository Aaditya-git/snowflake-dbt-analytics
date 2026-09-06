-- Orders that survived the header gate but ended up with no priceable lines.
--
-- Warn, not error, and deliberately so. This is the expected consequence of the line
-- gate doing its job: an order whose only item was an unknown SKU or a negative
-- quantity legitimately has nothing left to sell. A handful is the system working. A
-- spike is a catalog sync that failed, so the useful signal is the count over time,
-- not the presence of any row at all -- which is exactly what warn-with-a-threshold
-- expresses and a plain error does not.

{{ config(
    severity = 'warn',
    store_failures = true,
    warn_if = '>0',
    error_if = '>25'
) }}

with orders as (

    select * from {{ ref('silver_orders') }}

),

lines as (

    select distinct order_id from {{ ref('silver_order_items') }}

)

select
    orders.order_id,
    orders.order_date,
    orders.order_channel,
    orders.payload_item_count as lines_in_payload
from orders
left join lines on orders.order_id = lines.order_id
where lines.order_id is null
