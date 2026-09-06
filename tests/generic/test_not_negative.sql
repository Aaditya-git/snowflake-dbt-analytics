{#
    Fails on negative values, with zero configurable.

    `not_null` plus `accepted_range` from dbt_utils covers most of this, but a
    dedicated test reads better in the YAML and lets the zero rule be stated per
    column: a quantity of zero is a defect, a discount of zero is Tuesday.

    Returns one row per distinct offending value with an occurrence count, so a
    failure tells you what the bad values look like, not just how many there were.
#}
{% test not_negative(model, column_name, allow_zero=true) %}

select
    {{ column_name }} as failing_value,
    count(*)          as occurrences
from {{ model }}
where {{ column_name }} is not null
  and {{ column_name }} {% if allow_zero %}< 0{% else %}<= 0{% endif %}
group by {{ column_name }}

{% endtest %}
