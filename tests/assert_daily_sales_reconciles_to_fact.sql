-- The daily aggregate must sum to the same revenue as the fact it was built from.
--
-- Aggregates drift from their source when a GROUP BY key goes null, when a filter is
-- added to one and not the other, or when the aggregate is incremental and the fact
-- is not. All three produce a dashboard that disagrees with the detail behind it,
-- which is the fastest way to lose a stakeholder's trust in the whole warehouse.

with aggregate as (

    select
        coalesce(sum(gross_revenue), 0) as revenue,
        coalesce(sum(units_sold), 0)    as units
    from {{ ref('fct_daily_sales') }}

),

fact as (

    select
        coalesce(sum(line_amount), 0) as revenue,
        coalesce(sum(quantity), 0)    as units
    from {{ ref('fct_order_items') }}

)

select
    aggregate.revenue as aggregate_revenue,
    fact.revenue      as fact_revenue,
    aggregate.units   as aggregate_units,
    fact.units        as fact_units
from aggregate
cross join fact
where abs(aggregate.revenue - fact.revenue) > 0.01
   or aggregate.units <> fact.units
