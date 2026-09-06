-- Silver: one row per customer, conformed and trustworthy enough to join on.
-- Everything this model excluded is in silver_quarantine with a reason attached.

select
    customer_id,
    first_name,
    last_name,
    email,
    has_valid_email,
    country_code,
    signup_date,
    source_updated_at
from {{ ref('int_customers_cleaned') }}
where dq_failure_reason is null
