-- Date dimension generated with a date spine (dbt_utils).
with dates as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="to_date('2023-01-01')",
        end_date="to_date('2024-01-01')"
    ) }}

)

select
    cast(date_day as date)          as date_key,
    extract(year    from date_day)  as year,
    extract(quarter from date_day)  as quarter,
    extract(month   from date_day)  as month,
    extract(day     from date_day)  as day_of_month,
    dayname(date_day)               as day_name
from dates
