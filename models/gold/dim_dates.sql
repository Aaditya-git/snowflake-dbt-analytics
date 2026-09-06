-- Date dimension generated from a spine.
--
-- Runs to 2027 rather than stopping at the last order: a date dimension that ends
-- where the data ends turns the first order of the new year into a failing
-- referential integrity test, which is a self-inflicted 2am page.

with spine as (

    {{ dbt_utils.date_spine(
        datepart = "day",
        start_date = "to_date('2023-01-01')",
        end_date = "to_date('2027-01-01')"
    ) }}

)

select
    cast(date_day as date)              as date_key,
    extract(year    from date_day)      as calendar_year,
    extract(quarter from date_day)      as calendar_quarter,
    extract(month   from date_day)      as calendar_month,
    monthname(date_day)                 as month_name,
    extract(week    from date_day)      as week_of_year,
    extract(day     from date_day)      as day_of_month,
    dayofweekiso(date_day)              as day_of_week_iso,
    dayname(date_day)                   as day_name,
    dayofweekiso(date_day) in (6, 7)    as is_weekend,
    date_trunc('month',   date_day)::date   as first_day_of_month,
    last_day(date_day, 'month')             as last_day_of_month,
    cast(date_day as date) = current_date() as is_current_day
from spine
