-- Silver: the sellable product catalog. One row per product, priced.

select
    product_id,
    product_name,
    category,
    unit_price,
    source_updated_at
from {{ ref('int_products_cleaned') }}
where dq_failure_reason is null
