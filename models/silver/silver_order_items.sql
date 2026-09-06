-- Silver: one row per product per order, every line priceable against the catalog.

select
    order_id,
    line_number,
    product_id,
    quantity,
    order_ts
from {{ ref('int_order_items_cleaned') }}
where dq_failure_reason is null
