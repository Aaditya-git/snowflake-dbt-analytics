-- Customer dimension, type 1: one row per customer, current values only.
--
-- Type 1 rather than type 2 on purpose. Nothing here is used to value a transaction
-- the way a product price is, so keeping history would add a validity window that
-- every query then has to filter on for no analytical gain.

with customers as (

    select * from {{ ref('silver_customers') }}

)

select
    {{ dbt_utils.generate_surrogate_key(['customer_id']) }} as customer_key,
    customer_id,
    first_name,
    last_name,
    first_name || ' ' || last_name  as full_name,
    email,
    has_valid_email,
    country_code,
    signup_date,
    datediff(day, signup_date, current_date()) as days_since_signup
from customers
