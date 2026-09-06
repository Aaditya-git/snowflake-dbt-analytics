-- Every row the silver gate refused, in one place, with the reason attached.
--
-- The alternative -- a WHERE clause that drops bad rows and moves on -- is how a
-- pipeline ends up quietly 8% short with nobody able to say when it started. Rows
-- rejected here are still countable, still attributable to the dbt run that rejected
-- them, and still greppable by reason, so "revenue looks low" is a query rather than
-- an investigation.
--
-- Built by looping over the intermediate models so adding a new gated entity is one
-- line here, not another copy-pasted UNION ALL branch that drifts out of sync.

{{ config(materialized = 'table') }}

{% set gated_models = [
    {'model': 'int_customers_cleaned',   'entity': 'customer',   'key': 'cast(customer_id as string)'},
    {'model': 'int_products_cleaned',    'entity': 'product',    'key': 'cast(product_id as string)'},
    {'model': 'int_orders_cleaned',      'entity': 'order',      'key': 'cast(order_id as string)'},
    {'model': 'int_order_items_cleaned', 'entity': 'order_item', 'key': "cast(order_id as string) || '-' || cast(line_number as string)"}
] %}

{% for source in gated_models %}

select
    '{{ source.entity }}'      as entity,
    '{{ source.model }}'       as rejected_by_model,
    -- Nulled-out keys are exactly the rows that failed for being unkeyable, so the
    -- placeholder is the finding, not a formatting choice.
    coalesce({{ source.key }}, '<null key>') as record_key,
    dq_failure_reason,
    _batch_id                  as rejected_in_batch_id,
    _loaded_at                 as rejected_at
from {{ ref(source.model) }}
where dq_failure_reason is not null

{% if not loop.last %}union all{% endif %}

{% endfor %}
