-- Fact table at order-line grain: one row per product per order.
-- Foreign keys reference dim_customers, dim_products, and dim_dates.
with order_items as (

    select * from {{ ref('stg_order_items') }}

),

orders as (

    select * from {{ ref('stg_orders') }}

),

products as (

    select * from {{ ref('stg_products') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['order_items.order_id', 'order_items.product_id']) }} as order_item_key,
    order_items.order_id,
    orders.customer_id,
    order_items.product_id,
    orders.order_date,
    orders.order_channel,
    orders.promo_applied,
    order_items.quantity,
    products.unit_price,
    order_items.quantity * products.unit_price as line_amount
from order_items
inner join orders   on order_items.order_id   = orders.order_id
inner join products on order_items.product_id = products.product_id
