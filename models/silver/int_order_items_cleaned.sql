-- Silver, stage 1 of 2 for order lines: explode the payload's items[] array to
-- line grain with LATERAL FLATTEN, then label the lines that cannot be priced.
--
-- Sourced from silver_orders rather than bronze so a quarantined header cannot
-- leak its lines into the fact table through a side door.

{{ config(materialized = 'ephemeral') }}

with orders as (

    select
        silver_orders.order_id,
        silver_orders.order_ts,
        int_orders_cleaned.payload,
        int_orders_cleaned._loaded_at,
        int_orders_cleaned._batch_id
    from {{ ref('silver_orders') }} as silver_orders
    inner join {{ ref('int_orders_cleaned') }} as int_orders_cleaned
        on silver_orders.order_id = int_orders_cleaned.order_id

),

products as (

    select product_id from {{ ref('silver_products') }}

),

exploded as (

    select
        orders.order_id,
        orders.order_ts,
        orders._loaded_at,
        orders._batch_id,
        item.index                      as line_number,
        item.value:product_id::integer  as product_id,
        item.value:qty::integer         as quantity
    from orders,
         lateral flatten(input => orders.payload:items) as item

)

select
    exploded.*,
    case
        when exploded.product_id is null  then 'missing_product_id'
        when exploded.quantity is null    then 'missing_quantity'
        -- A zero or negative quantity is a return or a source defect. Either way it
        -- does not belong in a gross-sales fact, where it would net silently
        -- against real revenue and make the total look merely low rather than wrong.
        when exploded.quantity <= 0       then 'non_positive_quantity'
        -- No row in the priced catalog means either an unknown SKU or one that was
        -- itself quarantined for having no price. Both are unpriceable.
        when products.product_id is null  then 'unknown_or_unpriced_product'
    end as dq_failure_reason
from exploded
left join products on exploded.product_id = products.product_id
