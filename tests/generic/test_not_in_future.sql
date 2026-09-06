{#
    Fails on timestamps ahead of now, allowing a tolerance.

    Future-dated rows are the classic symptom of a source clock skew or a timezone
    that got dropped somewhere in the pipe, and they are quietly destructive: they
    sit outside every "last 30 days" filter, so the row is present, uncounted, and
    invisible until someone reconciles a total by hand.

    The tolerance exists because a few seconds of clock drift between the source and
    the warehouse is normal and should not page anybody.
#}
{% test not_in_future(model, column_name, tolerance_days=0) %}

select
    {{ column_name }} as failing_value
from {{ model }}
where cast({{ column_name }} as timestamp_ntz)
      > dateadd(day, {{ tolerance_days }}, cast(current_timestamp() as timestamp_ntz))

{% endtest %}
