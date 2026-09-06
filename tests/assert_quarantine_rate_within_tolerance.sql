-- No entity may reject more than `quarantine_error_pct` of its rows.
--
-- Individual rejections are normal and healthy -- that is what the gate is for. A
-- rejection *rate* crossing a threshold is different: it means the source changed
-- shape and the gate is now throwing away data that should have been loaded. Without
-- this, the pipeline's failure mode is to succeed loudly while getting quieter, and
-- the first person to notice is whoever reconciles a number by hand.
--
-- Threshold lives in dbt_project.yml so it can be tuned per environment without
-- touching SQL.

{{ config(
    severity = 'error',
    store_failures = true
) }}

select
    layer,
    model_name,
    row_count,
    rejected_row_count,
    rejected_pct
from {{ ref('dq_layer_reconciliation') }}
where rejected_pct > {{ var('quarantine_error_pct') }}
