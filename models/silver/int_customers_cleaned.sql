-- Silver, stage 1 of 2: clean and conform every bronze customer row, and label the
-- ones that cannot be trusted. This model decides nothing about what to keep -- it
-- attaches a `dq_failure_reason` and hands the split to silver_customers and
-- silver_quarantine, so the rule lives in exactly one place and the two outputs can
-- never disagree about what a good row is.
--
-- Ephemeral: it exists only to be inlined into its two consumers. Materialising it
-- would put a table in the warehouse that nobody is allowed to query directly.

{{ config(materialized = 'ephemeral') }}

with bronze as (

    select * from {{ ref('bronze_customers') }}

),

deduplicated as (

    -- The feed is CDC-style: a customer who changes their email arrives again as a
    -- second row with the same key. Newest source_updated_at wins, with _loaded_at
    -- as the tie-break so the ordering is total and the model is deterministic --
    -- a partial ordering here means the result changes between identical runs.
    select *
    from (
        select
            bronze.*,
            row_number() over (
                partition by customer_id
                order by source_updated_at desc, _loaded_at desc
            ) as _version_rank
        from bronze
    )
    where _version_rank = 1

),

cleaned as (

    select
        customer_id,
        initcap(trim(first_name))               as first_name,
        initcap(trim(last_name))                as last_name,
        -- Repair, not reject: a bad address costs you a marketing email, it does not
        -- make the customer's orders unreal. Null it out and flag it so the CRM team
        -- has a worklist instead of a silent empty string.
        case when {{ is_valid_email('email') }} then lower(trim(email)) end
                                                as email,
        {{ is_valid_email('email') }}           as has_valid_email,
        {{ normalize_country('country') }}      as country_code,
        signup_date,
        source_updated_at,
        _record_hash,
        _loaded_at,
        _batch_id
    from deduplicated

)

select
    cleaned.*,
    -- Rejection is reserved for rows that are structurally unusable. A customer with
    -- no id cannot be joined to anything and cannot be corrected downstream; a
    -- customer with a messy country can.
    case
        when customer_id is null  then 'missing_customer_id'
        when signup_date is null  then 'unparseable_signup_date'
    end as dq_failure_reason
from cleaned
