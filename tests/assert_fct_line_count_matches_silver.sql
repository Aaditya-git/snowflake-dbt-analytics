-- The fact table must have exactly one row per silver order line.
--
-- More rows means the point-in-time join to dim_products fanned out -- two versions
-- of a product whose validity windows overlap will match the same order twice and
-- double its revenue. Fewer rows means a version window has a gap and orders placed
-- inside it silently dropped out of the join. Both are invisible at row level: every
-- surviving row looks perfectly correct.
--
-- This is the single most important test in the project, because it is the only one
-- that fails when the SCD2 join is wrong.

with fact as (
    select count(*) as row_count from {{ ref('fct_order_items') }}
),

silver as (
    select count(*) as row_count from {{ ref('silver_order_items') }}
)

select
    fact.row_count   as fact_row_count,
    silver.row_count as silver_row_count,
    fact.row_count - silver.row_count as difference
from fact
cross join silver
where fact.row_count <> silver.row_count
