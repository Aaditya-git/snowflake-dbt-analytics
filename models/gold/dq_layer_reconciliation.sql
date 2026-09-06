-- Row counts across every layer, plus what each layer rejected, as a queryable table.
--
-- This is the model that answers "is the pipeline healthy" without anyone reading a
-- log. Rejection counts sitting next to row counts make a slow leak visible as a
-- trend: a gate that rejected 3 orders yesterday and 3,000 today is a source system
-- that broke overnight, and that is the kind of thing that otherwise gets noticed a
-- week later by someone in finance.

{{ config(materialized = 'table') }}

{% set layer_models = [
    ('bronze', 'bronze_customers'),
    ('bronze', 'bronze_products'),
    ('bronze', 'bronze_orders'),
    ('silver', 'silver_customers'),
    ('silver', 'silver_products'),
    ('silver', 'silver_orders'),
    ('silver', 'silver_order_items'),
    ('gold',   'dim_customers'),
    ('gold',   'dim_products'),
    ('gold',   'fct_order_items'),
    ('gold',   'fct_daily_sales')
] %}

with row_counts as (

    {% for layer, model_name in layer_models %}
    select
        '{{ layer }}'      as layer,
        '{{ model_name }}' as model_name,
        count(*)           as row_count
    from {{ ref(model_name) }}
    {% if not loop.last %}union all{% endif %}
    {% endfor %}

),

rejections as (

    select
        entity,
        count(*) as rejected_row_count
    from {{ ref('silver_quarantine') }}
    group by entity

),

-- Maps a model to the quarantine entity that feeds it, so a rejection count can sit
-- on the same row as the count that survived.
model_entity as (

    select * from (
        values
            ('silver_customers',   'customer'),
            ('silver_products',    'product'),
            ('silver_orders',      'order'),
            ('silver_order_items', 'order_item')
    ) as t (model_name, entity)

)

select
    row_counts.layer,
    row_counts.model_name,
    row_counts.row_count,
    coalesce(rejections.rejected_row_count, 0) as rejected_row_count,
    round(
        100.0 * coalesce(rejections.rejected_row_count, 0)
        / nullif(row_counts.row_count + coalesce(rejections.rejected_row_count, 0), 0)
    , 2) as rejected_pct,
    cast('{{ run_started_at.strftime("%Y-%m-%d %H:%M:%S") }}' as timestamp_ntz) as measured_at
from row_counts
left join model_entity  on row_counts.model_name = model_entity.model_name
left join rejections    on model_entity.entity   = rejections.entity
