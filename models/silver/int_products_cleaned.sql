-- Silver, stage 1 of 2 for the product catalog. Same split-and-label pattern as
-- int_customers_cleaned.

{{ config(materialized = 'ephemeral') }}

with bronze as (

    select * from {{ ref('bronze_products') }}

),

deduplicated as (

    select *
    from (
        select
            bronze.*,
            row_number() over (
                partition by product_id
                order by source_updated_at desc, _loaded_at desc
            ) as _version_rank
        from bronze
    )
    where _version_rank = 1

),

cleaned as (

    select
        product_id,
        trim(product_name)  as product_name,
        -- Repair: an unclassified product still sells. 'Uncategorized' is an honest
        -- bucket that shows up in a GROUP BY; a null silently vanishes from one.
        coalesce(nullif(trim(category), ''), 'Uncategorized') as category,
        unit_price,
        source_updated_at,
        _record_hash,
        _loaded_at,
        _batch_id
    from deduplicated

)

select
    cleaned.*,
    -- A product with no price cannot produce a line amount, so letting it through
    -- would put a null into revenue. Reject it here and the fact table stays whole.
    case
        when product_id is null    then 'missing_product_id'
        when product_name is null
          or product_name = ''     then 'missing_product_name'
        when unit_price is null    then 'missing_unit_price'
        when unit_price <= 0       then 'non_positive_unit_price'
    end as dq_failure_reason
from cleaned
