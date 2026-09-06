{#
    Boolean expression for "this looks like a deliverable address".

    Deliberately not a full RFC 5322 implementation -- that regex is famously
    unreadable and rejects addresses that work in practice. This catches the failure
    mode that actually shows up in extracts: a missing @, a missing TLD, or a value
    that is really a note somebody typed into the email field.

    Written with [.] rather than \. so it survives Snowflake's backslash escaping in
    string literals without needing dollar-quoting.
#}
{% macro is_valid_email(column_name) -%}
    (
        {{ column_name }} is not null
        and regexp_like(trim({{ column_name }}),
                        '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}$')
    )
{%- endmacro %}
