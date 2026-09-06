-- Star schema centre. Grain: one row per product per order.
--
-- The grain is stated in one line at the top because it is the only thing about a
-- fact table you cannot recover by reading the SQL, and every duplicate-revenue bug
-- starts with somebody joining to it at a grain they assumed rather than checked.
--
-- Incremental on order_date. A fact table is the model that eventually costs real
-- money to rebuild, and order history is append-mostly, so the pattern is worth
-- establishing while the table is still small enough that it does not matter.

{{ config(
    materialized = 'incremental',
    unique_key = 'order_item_key',
    incremental_strategy = 'merge',
    on_schema_change = 'append_new_columns',
    cluster_by = ['order_date']
) }}

with order_items as (

    select * from {{ ref('silver_order_items') }}

),

orders as (

    select * from {{ ref('silver_orders') }}

    {% if is_incremental() %}
    -- Three-day lookback rather than a strict high-water mark: orders arrive late,
    -- and a corrected line for a settled order has to be able to overwrite the
    -- version already in the table. The merge on order_item_key makes reprocessing
    -- that window idempotent, so the only cost of the overlap is a little compute.
    where order_date >= (
        select dateadd(day, -3, coalesce(max(order_date), to_date('1900-01-01')))
        from {{ this }}
    )
    {% endif %}

),

products as (

    select * from {{ ref('dim_products') }}

),

customers as (

    select customer_key, customer_id from {{ ref('dim_customers') }}

),

joined as (

    select
        order_items.order_id,
        order_items.line_number,
        order_items.product_id,
        orders.customer_id,
        orders.order_ts,
        orders.order_date,
        orders.order_channel,
        orders.order_device,
        orders.promo_applied,
        orders.promo_code,
        order_items.quantity,

        customers.customer_key,
        products.product_key,
        products.category as product_category,
        -- Point-in-time price: value the line at the version of the product that was
        -- in effect when the order was placed, not at today's price. This is the
        -- entire reason dim_products is type 2.
        products.unit_price
    from order_items
    inner join orders
        on order_items.order_id = orders.order_id
    inner join products
        on order_items.product_id = products.product_id
       and orders.order_ts >= products.valid_from
       and orders.order_ts <  products.valid_to
    inner join customers
        on orders.customer_id = customers.customer_id

)

select
    -- Surrogate key on (order_id, line_number) rather than (order_id, product_id):
    -- the same SKU can legitimately appear twice on one order, and keying on the
    -- product would collapse those two lines into one and lose revenue.
    {{ dbt_utils.generate_surrogate_key(['order_id', 'line_number']) }} as order_item_key,

    -- Foreign keys
    order_id,
    line_number,
    customer_key,
    product_key,
    customer_id,
    product_id,
    order_date,

    -- Degenerate dimensions (order attributes that have no dimension of their own)
    order_ts,
    order_channel,
    order_device,
    promo_applied,
    promo_code,
    product_category,

    -- Measures
    quantity,
    unit_price,
    round(quantity * unit_price, 2) as line_amount
from joined
