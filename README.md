# snowflake-dbt-analytics

A Snowflake + dbt warehouse built as a **medallion architecture** (bronze / silver /
gold), with a data quality layer that quarantines bad rows instead of dropping them,
type 2 history on the product dimension, and **141 tests** across five tiers.

Raw semi-structured JSON goes in one end. A tested star schema, a daily aggregate,
and a pipeline health table come out the other.

---

## Architecture

```
seeds/  (landing zone, everything typed as text)
   raw_customers      raw_products      raw_orders
        |                  |                 |
        v                  v                 v
+--------------------------------------------------------------+
|  BRONZE   tables, typed, audit-stamped, never filtered        |
|  bronze_customers    bronze_products    bronze_orders (incr.) |
+--------------------------------------------------------------+
        |                  |                 |
        v                  v                 v
+--------------------------------------------------------------+
|  SILVER   views, deduplicated, conformed, quality-gated       |
|                                                               |
|  int_*_cleaned  (ephemeral: clean + label dq_failure_reason)  |
|        |                                    |                 |
|   passes gate                          fails gate             |
|        v                                    v                 |
|  silver_customers   silver_products    silver_quarantine      |
|  silver_orders      silver_order_items                        |
+--------------------------------------------------------------+
        |                                     |
        v                                     |
   products_snapshot  (SCD2)                  |
        |                                     |
        v                                     v
+--------------------------------------------------------------+
|  GOLD   tables, dimensional models the BI layer reads         |
|  dim_customers  dim_products (SCD2)  dim_dates                |
|  fct_order_items (incr.)  fct_daily_sales                     |
|  dq_layer_reconciliation                                      |
+--------------------------------------------------------------+
```

### What each layer is allowed to do

| Layer | Materialization | Responsibility | Explicitly not its job |
|---|---|---|---|
| **Landing** (seeds) | table, all text | Hold exactly what arrived | Casting, since a cast can reject a row |
| **Bronze** | table (orders incremental) | Apply types with `try_to_*`, stamp audit columns | Filtering, deduplicating, or judging a row |
| **Silver** | view (int models ephemeral) | Deduplicate, conform, repair, gate | Business aggregation or dimensional modeling |
| **Gold** | table (fact incremental) | Star schema, surrogate keys, aggregates | Cleaning, which should already be done |

The rule that makes the split worth having: **bronze warns, silver enforces.** A bad
row from an upstream team is their outage, and erroring on it in bronze would make it
ours. Bronze tests are `severity: warn` so the signal still appears in the run
summary. Silver tests are errors, because silver is the layer that makes promises.

---

## Star schema (gold)

```
                    +----------------+
                    |  dim_customers |   type 1
                    +----------------+
                            | customer_key
                            |
+----------------+  +-------------------+  +-------------+
|  dim_products  |--|  fct_order_items  |--|  dim_dates  |
|   type 2 SCD   |  |  grain: one row   |  |  2023-2026  |
+----------------+  |  per product      |  +-------------+
   product_key      |  per order        |    date_key
                    +-------------------+
                            |
                            v
                    +-------------------+
                    |  fct_daily_sales  |  aggregate
                    +-------------------+
```

`dim_products` is type 2 because an order placed in May has to be valued at May's
price. `fct_order_items` joins it on a point-in-time predicate
(`order_ts >= valid_from and order_ts < valid_to`) rather than on `product_id` alone,
so a catalog price change does not silently rewrite a finished quarter's revenue.

`dim_customers` is deliberately type 1. Nothing on it is used to value a transaction,
so history would add a validity window every query then has to filter on for no gain.

---

## Testing

141 tests, in five tiers.

**1. Generic, built in.** `not_null`, `unique`, `relationships`, `accepted_values`,
on keys, foreign keys, and every enumerated column.

**2. Generic, from packages.** `dbt_utils` for the tests that describe a table rather
than a column (`unique_combination_of_columns` for composite grain,
`expression_is_true` for invariants, `not_null_proportion` for coverage that is
allowed to be partial but not to collapse, `accepted_range`). `dbt_expectations` for
distributional checks (`expect_table_row_count_to_be_between`,
`expect_column_values_to_be_between`, `expect_column_values_to_not_be_in_set`).

**3. Custom generic tests** in `tests/generic/`:

| Test | What it catches |
|---|---|
| `not_negative(allow_zero=)` | Negative measures, with zero configurable per column, because a quantity of zero is a defect and a discount of zero is Tuesday |
| `valid_email` | Present but malformed addresses. Nulls pass, so a missing address and a corrupted one stay separately diagnosable |
| `not_in_future(tolerance_days=)` | Clock skew and dropped timezones, which produce rows that sit outside every "last 30 days" filter and go uncounted |
| `string_is_trimmed` | Leading and trailing whitespace, invisible in every tool a human will use, but two distinct values to a `GROUP BY` |
| `sum_matches_upstream` | A total that no longer matches the same total recomputed upstream, which is the only way to see a join that fanned out |

**4. Singular tests** in `tests/`, for assertions that span models:

| Test | What it catches |
|---|---|
| `assert_fct_line_count_matches_silver` | The SCD2 join fanning out or dropping rows. Every individual row still looks correct when this breaks |
| `assert_flatten_preserved_every_line` | `LATERAL FLATTEN` silently yielding nothing after an upstream key rename, by comparing the recorded `items[]` array length against the lines produced |
| `assert_no_overlapping_product_versions` | Type 2 windows that overlap, caught on the dimension rather than three models downstream as an unexplained revenue jump |
| `assert_daily_sales_reconciles_to_fact` | An aggregate drifting from the detail behind it |
| `assert_quarantine_rate_within_tolerance` | A rejection **rate** crossing a threshold, meaning the source changed shape and the gate is now discarding good data |
| `assert_orders_have_at_least_one_line` | Orders left with nothing sellable. `severity: warn` with `error_if: '>25'`, because a handful is the gate working and a spike is a catalog sync that failed |

**5. Custom macros** in `macros/`: `generate_schema_name` (prod gets bare
`BRONZE`/`SILVER`/`GOLD` schemas, dev stays namespaced per engineer),
`audit_columns` (stamps `_record_hash`, `_source_system`, `_loaded_at`, and the dbt
`invocation_id` as `_batch_id`, so any row traces back to the run that produced it),
`normalize_country` (dict-driven ISO 3166 conforming), `is_valid_email`.

`store_failures` is off by default and switched on only for the tests that exist to
be investigated. A table per test, failing or not, is 140 pieces of clutter around
the three that matter.

---

## The data quality layer

The seed data contains deliberate defects, one per failure mode a real feed produces.
Nothing is dropped by a bare `WHERE` clause. Every rejected row lands in
`silver_quarantine` with the reason and the `invocation_id` of the run that rejected
it, so "revenue looks low" is a query rather than an investigation.

| Defect in the seed | Layer that handles it | What happens |
|---|---|---|
| CDC replay: same customer, two rows | silver | Deduplicated, newest `source_updated_at` wins |
| `' Mia '`, `'ETHAN.BROWN@...'` | silver | Trimmed and cased, asserted by `string_is_trimmed` |
| `USA` / `United States` / `us` | silver | Conformed to `US` by `normalize_country` |
| Malformed email | silver | **Repaired**, not rejected. Nulled and flagged `has_valid_email = false` |
| Customer row with no id | silver | **Rejected**, `missing_customer_id`. Cannot be keyed, cannot be fixed downstream |
| Product with no price | silver | **Rejected**, `missing_unit_price`. Letting it through puts a null into revenue |
| Product with no category | silver | Repaired to `'Uncategorized'`, which shows up in a `GROUP BY` where a null vanishes |
| Order with unparseable JSON | bronze then silver | `try_parse_json` returns null instead of failing the run, silver rejects it as `malformed_json_payload` |
| Order dated 2030 | silver | Rejected, `future_dated_order` |
| Order for an unknown customer | silver | Rejected, `unknown_customer` |
| Order replayed on retry | silver | Deduplicated to the latest version, so it does not double-count into revenue |
| Channel `'kiosk'` | silver | **Conformed** to `'other'`, not rejected. A new sales surface should keep its revenue in the totals and still be visible |
| `promo_applied` with no promo code | silver | Repaired to `false`. The code is the evidence |
| Line with quantity 0 or -2 | silver | Rejected. A negative quantity in a gross-sales fact nets silently against real revenue and makes the total look low rather than wrong |
| Line for a nonexistent SKU | silver | Rejected, `unknown_or_unpriced_product` |

`dq_layer_reconciliation` puts row counts and rejection rates for every model in one
queryable table, so pipeline health is a `SELECT` rather than a log grep, and a source
that is degrading rather than failing shows up as a trend.

---

## Running it

```bash
dbt deps                    # dbt_utils + dbt_expectations
dbt seed                    # load the landing zone
dbt build                   # bronze -> silver -> snapshot -> gold, tests in DAG order
dbt docs generate && dbt docs serve
```

`dbt build` is the right command here rather than `run` then `test`: it interleaves
them, so a model whose upstream test failed does not get built on bad data.

Useful selectors:

```bash
dbt build --select tag:silver+          # silver and everything downstream
dbt test  --select fct_order_items      # one model's tests
dbt test  --select test_type:singular   # the cross-model assertions
dbt build --full-refresh                # rebuild the incremental models from scratch
```

To see the type 2 dimension actually do something, change a price in
`seeds/raw_products.csv`, then:

```bash
dbt seed && dbt snapshot && dbt build --select dim_products+
```

`dim_products` will now have two versions of that product, and `fct_order_items` will
keep valuing older orders at the old price.

---

## Stack

| Layer | Tech |
|---|---|
| Warehouse | Snowflake (VARIANT, `LATERAL FLATTEN`, `try_to_*`, `MERGE`) |
| Transformation | dbt 1.10+ |
| Languages | SQL, Jinja |
| Packages | `dbt_utils`, `dbt_expectations` |
| Patterns | Medallion, star schema, SCD2 snapshots, incremental merge, quarantine gating |

## Project layout

```
seeds/                    raw_customers, raw_products, raw_orders (+ _seeds.yml)
models/bronze/            typed, audit-stamped, unfiltered  (+ _bronze.yml)
models/silver/            int_*_cleaned (ephemeral), silver_*, silver_quarantine
models/gold/              dim_*, fct_*, dq_layer_reconciliation  (+ _gold.yml)
snapshots/                products_snapshot (SCD2)
macros/                   generate_schema_name, audit_columns, normalize_country,
                          is_valid_email
tests/                    6 singular cross-model assertions
tests/generic/            5 custom generic tests
```
