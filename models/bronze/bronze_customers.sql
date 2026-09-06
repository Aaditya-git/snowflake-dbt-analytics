-- Bronze: land the customer feed with types applied and nothing else.
--
-- try_to_* rather than a hard cast is the whole discipline of this layer. A hard
-- cast makes one malformed date abort the load of an otherwise good file; try_to_*
-- turns it into a null that the silver gate can quarantine and a human can go look
-- at. Bronze does not get to decide a row is bad, it only records what arrived.

with source as (

    select * from {{ ref('raw_customers') }}

),

typed as (

    select
        try_to_number(customer_id)          as customer_id,
        first_name,
        last_name,
        email,
        country,
        try_to_date(signup_date)            as signup_date,
        try_to_timestamp_ntz(updated_at)    as source_updated_at
    from source

)

select
    typed.*,
    {{ audit_columns(['customer_id', 'source_updated_at']) }}
from typed
