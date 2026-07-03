# snowflake-dbt-analytics

ELT and dimensional data modeling on **Snowflake** with **dbt**: raw semi-structured
data (JSON/Parquet-style `VARIANT`) transformed into clean, tested, analytics-ready
**star-schema** tables.

## What this project does

1. **Raw (seeds):** load source data, including an orders feed whose `payload`
   column carries a **semi-structured JSON** document (channel, device, promo, and a
   nested `items[]` array).
2. **Staging (dbt views):** type and clean each source. `stg_orders` parses the JSON
   `VARIANT` into typed columns; `stg_order_items` explodes the `items[]` array with
   `LATERAL FLATTEN` to reach order-line grain.
3. **Marts (dbt tables):** a **star schema** built from staging:
   - `dim_customers`, `dim_products`, `dim_dates` (date spine)
   - `fct_order_items` (fact, one row per product per order, with `line_amount`)
4. **Tests:** `not_null`, `unique`, `relationships`, and `accepted_values` across
   staging and marts (see the `_staging.yml` / `_marts.yml` files).
5. **Docs & lineage:** model and column descriptions power `dbt docs`.

## Data model (star schema)

```
                +----------------+
                |  dim_customers |
                +----------------+
                        |
+--------------+  +------------------+  +-------------+
| dim_products |--|  fct_order_items |--|  dim_dates  |
+--------------+  +------------------+  +-------------+
        (fact grain: one row per product per order)
```

## Stack

| Layer          | Tech                          |
|----------------|-------------------------------|
| Warehouse      | Snowflake                     |
| Transformation | dbt (staging views + marts)   |
| Languages      | SQL, Jinja                    |
| Packages       | dbt_utils                     |

## Project layout

```
seeds/                raw_customers, raw_products, raw_orders (JSON payload)
models/staging/       stg_customers, stg_products, stg_orders, stg_order_items (+ tests/docs)
models/marts/         dim_customers, dim_products, dim_dates, fct_order_items (+ tests/docs)
```

## Getting started

```bash
# 1. configure a Snowflake connection (see profiles.example.yml)
cp profiles.example.yml ~/.dbt/profiles.yml   # then edit, or set the SNOWFLAKE_* env vars

# 2. install packages and build
dbt deps
dbt seed          # load raw data
dbt run           # build staging + marts
dbt test          # run data-quality tests
dbt docs generate && dbt docs serve   # browse models + lineage
```
