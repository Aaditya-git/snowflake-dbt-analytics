{#
    Slowly changing dimension (type 2) over the product catalog.

    The source system overwrites a product row when its price changes, so it can only
    ever answer "what does this cost now". That is the wrong question for a fact table:
    an order placed in May has to be valued at May's price, and re-pricing history
    every time a catalog changes is how a finished quarter's revenue starts moving.
    The snapshot captures each version as it appears and stamps it with a validity
    window, which is what makes the point-in-time join in fct_order_items possible.

    Strategy is `check` rather than `timestamp` because the feed's updated_at is not
    reliably touched on every edit -- trusting it would silently miss changes.
#}

{% snapshot products_snapshot %}

{{ config(
    schema = 'snapshots',
    unique_key = 'product_id',
    strategy = 'check',
    check_cols = ['product_name', 'category', 'unit_price'],
    hard_deletes = 'invalidate'
) }}

select
    product_id,
    product_name,
    category,
    unit_price
from {{ ref('silver_products') }}

{% endsnapshot %}
