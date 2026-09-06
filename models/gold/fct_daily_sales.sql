-- Daily sales by channel, pre-aggregated off fct_order_items.
--
-- Exists because every dashboard on this data asks the same question at the same
-- grain, and letting each one re-scan the line-level fact is how a warehouse bill
-- gets interesting. Rebuilt in full rather than incrementally: it is small, and a
-- day's total has to be free to move when a late line lands.

with order_items as (

    select * from {{ ref('fct_order_items') }}

)

select
    order_date,
    order_channel,
    count(distinct order_id)                as order_count,
    count(*)                                as line_count,
    count(distinct customer_id)             as customer_count,
    sum(quantity)                           as units_sold,
    round(sum(line_amount), 2)              as gross_revenue,
    round(sum(case when promo_applied then line_amount else 0 end), 2)
                                            as promo_revenue,
    -- Guarded even though order_count cannot be zero within a group that exists.
    -- The guard costs nothing and survives the day somebody adds a filter above it.
    round(sum(line_amount) / nullif(count(distinct order_id), 0), 2)
                                            as avg_order_value
from order_items
group by order_date, order_channel
