{#
    Schema naming.

    dbt's default behaviour is to concatenate the target schema and the model's
    custom schema, which gives you `DBT_BRONZE`, `DBT_SILVER`, ... That is what you
    want in dev, where every engineer builds into their own sandbox and needs the
    prefix to avoid collisions. It is not what you want in prod, where downstream
    consumers hard-code `ANALYTICS.GOLD.FCT_ORDER_ITEMS` and cannot cope with a
    developer's username in the path.

    So: prod gets the bare layer name, everything else stays namespaced.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}

    {%- if custom_schema_name is none -%}
        {{ default_schema }}

    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}

    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}

    {%- endif -%}

{%- endmacro %}
