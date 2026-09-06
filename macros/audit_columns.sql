{#
    Audit columns stamped onto every bronze table.

    `_batch_id` is dbt's invocation_id, which means any row in the warehouse can be
    tied back to the exact run that produced it -- the first question anyone asks
    when a number looks wrong is "when did this land and from what run", and without
    this you are reduced to guessing from the load timestamp.

    Args:
      hash_columns: columns that make a source record unique. Hashing them gives a
                    stable key for incremental merges and makes a replayed source
                    file idempotent instead of duplicating.
#}
{% macro audit_columns(hash_columns) %}
    {{ dbt_utils.generate_surrogate_key(hash_columns) }} as _record_hash,
    '{{ var("source_system") }}' as _source_system,
    cast('{{ run_started_at.strftime("%Y-%m-%d %H:%M:%S") }}' as timestamp_ntz) as _loaded_at,
    '{{ invocation_id }}' as _batch_id
{% endmacro %}
