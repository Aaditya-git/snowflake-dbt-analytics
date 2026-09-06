-- Every element of the payload's items[] array must be accounted for: either it made
-- it into silver_order_items or it is in the quarantine with a reason.
--
-- LATERAL FLATTEN over a null or absent array yields no rows rather than an error,
-- so an upstream schema change that renames `items` degrades to "orders exist, lines
-- do not" with nothing anywhere reporting a failure. Comparing the array length
-- recorded on the header against the lines actually produced closes that hole.

{{ config(store_failures = true) }}

with expected as (

    select
        order_id,
        payload_item_count as expected_line_count
    from {{ ref('silver_orders') }}

),

actual as (

    -- The pre-gate model: kept lines and rejected lines together, which is what
    -- "the FLATTEN produced these" means.
    select
        order_id,
        count(*) as actual_line_count
    from {{ ref('int_order_items_cleaned') }}
    group by order_id

)

select
    expected.order_id,
    expected.expected_line_count,
    coalesce(actual.actual_line_count, 0) as actual_line_count
from expected
left join actual on expected.order_id = actual.order_id
where expected.expected_line_count <> coalesce(actual.actual_line_count, 0)
