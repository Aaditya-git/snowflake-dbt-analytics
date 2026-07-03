# snowflake-dbt-analytics

ELT and dimensional data modeling on **Snowflake** with **dbt** — turning raw,
semi-structured data (JSON/Parquet) into clean, tested, analytics-ready star-schema
tables.

## What this project does

- **Ingest (raw):** load semi-structured JSON/Parquet into Snowflake using `VARIANT` columns.
- **Stage (dbt):** flatten and clean raw data into typed staging models.
- **Model (dbt):** build a **star/snowflake schema** — fact and dimension tables in the marts layer.
- **Test:** enforce data quality with dbt tests (`not_null`, `unique`, `relationships`, accepted values).
- **Document:** generate model/column docs and lineage with `dbt docs`.

## Stack

| Layer | Tech |
|-------|------|
| Warehouse | Snowflake |
| Transformation | dbt (staging + marts) |
| Language | SQL, Python |
| Orchestration | (scheduled dbt runs) |

## Architecture

```
raw (JSON/Parquet -> VARIANT)  ->  staging (dbt)  ->  marts (dbt: dims + facts)  ->  BI / analytics
```

## Status

Active build-out. Core ELT flow and dimensional models are being layered in; see
the `models/` directory for staging and marts. README and docs updated as the
project grows.

## Getting started

```bash
# configure your Snowflake profile in ~/.dbt/profiles.yml
dbt deps
dbt seed
dbt run
dbt test
dbt docs generate && dbt docs serve
```
