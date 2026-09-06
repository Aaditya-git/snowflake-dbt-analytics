-- Bronze: land the product catalog with types applied and nothing else.

with source as (

    select * from {{ ref('raw_products') }}

),

typed as (

    select
        try_to_number(product_id)           as product_id,
        product_name,
        category,
        try_to_number(unit_price, 10, 2)    as unit_price,
        try_to_timestamp_ntz(updated_at)    as source_updated_at
    from source

)

select
    typed.*,
    {{ audit_columns(['product_id', 'source_updated_at']) }}
from typed
