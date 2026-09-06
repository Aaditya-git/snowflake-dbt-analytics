{#
    Fails when a measure's total does not match the same total recomputed upstream.

    This is the test that catches the failure mode row-level tests structurally
    cannot: a join that fans out. Every row can be individually valid, every key can
    be non-null and unique, and the table can still carry twice the revenue it should
    because a dimension had two versions matching one fact. Comparing the aggregate
    against an independent recomputation is the only thing that notices.

    `tolerance` is a float comparison allowance, not a fudge factor -- set it to the
    rounding you actually apply and no wider.

    Args:
      compare_model:      a ref() to reconcile against
      compare_expression: the expression summing to the same number over there
      tolerance:          largest difference still considered a match
#}
{% test sum_matches_upstream(model, column_name, compare_model, compare_expression, tolerance=0.01) %}

with model_total as (

    select coalesce(sum({{ column_name }}), 0) as total
    from {{ model }}

),

upstream_total as (

    select coalesce(sum({{ compare_expression }}), 0) as total
    from {{ compare_model }}

)

select
    model_total.total                            as model_total,
    upstream_total.total                         as upstream_total,
    abs(model_total.total - upstream_total.total) as difference
from model_total
cross join upstream_total
where abs(model_total.total - upstream_total.total) > {{ tolerance }}

{% endtest %}
