-- Silver: one row per order, deduplicated, conformed, and guaranteed to join to a
-- known customer. This is the header grain -- line items are in silver_order_items.

select
    order_id,
    customer_id,
    order_ts,
    order_date,
    order_channel,
    order_device,
    promo_applied,
    promo_code,
    payload_item_count
from {{ ref('int_orders_cleaned') }}
where dq_failure_reason is null
