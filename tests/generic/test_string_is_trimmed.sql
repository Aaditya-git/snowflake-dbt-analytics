{#
    Fails on leading or trailing whitespace.

    Worth a test of its own because whitespace is invisible in every tool anyone will
    use to look at the data. ' Mia' and 'Mia' are two customers in a GROUP BY, two
    keys in a join, and one value to the human reading the report -- which makes this
    the cheapest test here and one of the more useful ones. Belongs on silver columns
    that were supposed to have been normalised, as a check on the normalisation.
#}
{% test string_is_trimmed(model, column_name) %}

select
    {{ column_name }} as failing_value,
    count(*)          as occurrences
from {{ model }}
where {{ column_name }} is not null
  and {{ column_name }} <> trim({{ column_name }})
group by {{ column_name }}

{% endtest %}
