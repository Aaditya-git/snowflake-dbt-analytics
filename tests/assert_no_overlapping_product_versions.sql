-- Type 2 integrity: no product may have two versions valid at the same instant.
--
-- An overlap is what makes the point-in-time join in fct_order_items fan out. Testing
-- for it here, on the dimension, means a broken snapshot is caught where it broke
-- rather than three models downstream as an unexplained revenue jump.

with versions as (

    select * from {{ ref('dim_products') }}

)

select
    earlier.product_id,
    earlier.product_key as earlier_version_key,
    later.product_key   as later_version_key,
    earlier.valid_from  as earlier_valid_from,
    earlier.valid_to    as earlier_valid_to,
    later.valid_from    as later_valid_from,
    later.valid_to      as later_valid_to
from versions as earlier
inner join versions as later
    on earlier.product_id  = later.product_id
   and earlier.product_key < later.product_key
-- Half-open intervals: [valid_from, valid_to). Two intervals overlap when each
-- starts before the other ends.
where earlier.valid_from < later.valid_to
  and later.valid_from   < earlier.valid_to
