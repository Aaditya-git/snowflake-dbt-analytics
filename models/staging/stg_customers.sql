with source as (

    select * from {{ ref('raw_customers') }}

)

select
    customer_id,
    first_name,
    last_name,
    lower(email)        as email,
    country,
    signup_date::date   as signup_date
from source
