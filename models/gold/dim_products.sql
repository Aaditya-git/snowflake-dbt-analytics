-- Product dimension, type 2: one row per version of a product, with a validity
-- window. `product_key` is the surrogate key the fact joins on; `product_id` is the
-- natural key that repeats across versions.

with versions as (

    select * from {{ ref('products_snapshot') }}

),

windowed as (

    select
        product_id,
        product_name,
        category,
        unit_price,

        -- The first version's validity is backdated rather than taken from the
        -- snapshot. dbt stamps dbt_valid_from with the moment the snapshot first ran,
        -- which is always later than the historical orders being loaded alongside it,
        -- so an honest window would fail to cover any of them and the point-in-time
        -- join in fct_order_items would silently return zero rows. Treating the
        -- earliest version as "in effect since the beginning of time" is the standard
        -- fix and is only ever wrong about prices from before the warehouse existed.
        case
            when row_number() over (
                     partition by product_id order by dbt_valid_from
                 ) = 1
            then to_timestamp_ntz('1900-01-01 00:00:00')
            else dbt_valid_from
        end as valid_from,

        -- An open-ended version gets a sentinel rather than a null so the fact join
        -- can use a plain BETWEEN instead of a null-handling OR, which reads better
        -- and lets the optimiser use the range.
        coalesce(dbt_valid_to, to_timestamp_ntz('9999-12-31 00:00:00')) as valid_to,

        dbt_valid_to is null as is_current
    from versions

)

select
    {{ dbt_utils.generate_surrogate_key(['product_id', 'valid_from']) }} as product_key,
    product_id,
    product_name,
    category,
    unit_price,
    valid_from,
    valid_to,
    is_current
from windowed
