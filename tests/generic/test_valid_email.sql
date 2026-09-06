{#
    Fails on values that are present but not shaped like an email address.

    Nulls pass. A missing address is a separate fact from a malformed one and
    deserves its own `not_null` test, otherwise one failure hides the other and you
    cannot tell an empty column from a corrupted one.
#}
{% test valid_email(model, column_name) %}

select
    {{ column_name }} as failing_value
from {{ model }}
where {{ column_name }} is not null
  and not {{ is_valid_email(column_name) }}

{% endtest %}
