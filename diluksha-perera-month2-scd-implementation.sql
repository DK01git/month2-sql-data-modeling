-- EXECUTION ORDER:
--   1. Populate dim_date       (generated — no source dependency)
--   2. Load dim_store          (SCD Type 1)
--   3. Load dim_customer       (SCD Type 2)
--   4. Load dim_product        (SCD Type 2)
--   5. Load dim_promotion      (SCD Type 1)
--   6. Load fact_sales         (depends on all dimensions)
--
-- PREREQUISITE:
--   All staging tables must be populated before running
--   these scripts. See sample-data.sql for INSERT statements.
-- ============================================================


-- ============================================================
-- STEP 1: POPULATE dim_date
-- Generates one row per calendar day from 2020-01-01
-- to 2030-12-31 using generate_series
-- Fiscal year starts July 1
-- Expected rows: 4018
-- ============================================================

INSERT INTO warehouse.dim_date (
    date_key, full_date, day_of_week, day_name, day_of_month,
    day_of_year, week_of_year, month_number, month_name,
    quarter_number, quarter_name, year_number,
    fiscal_year, fiscal_quarter, is_weekend
)
SELECT
    TO_CHAR(dt, 'YYYYMMDD')::INTEGER        AS date_key,
    dt                                       AS full_date,
    EXTRACT(ISODOW FROM dt)::SMALLINT        AS day_of_week,
    TO_CHAR(dt, 'Day')                       AS day_name,
    EXTRACT(DAY FROM dt)::SMALLINT           AS day_of_month,
    EXTRACT(DOY FROM dt)::SMALLINT           AS day_of_year,
    EXTRACT(WEEK FROM dt)::SMALLINT          AS week_of_year,
    EXTRACT(MONTH FROM dt)::SMALLINT         AS month_number,
    TO_CHAR(dt, 'Month')                     AS month_name,
    EXTRACT(QUARTER FROM dt)::SMALLINT       AS quarter_number,
    'Q' || EXTRACT(QUARTER FROM dt)::TEXT    AS quarter_name,
    EXTRACT(YEAR FROM dt)::SMALLINT          AS year_number,
    CASE WHEN EXTRACT(MONTH FROM dt) >= 7
         THEN EXTRACT(YEAR FROM dt)::SMALLINT + 1
         ELSE EXTRACT(YEAR FROM dt)::SMALLINT
    END                                      AS fiscal_year,
    CASE
        WHEN EXTRACT(MONTH FROM dt) IN (7,8,9)    THEN 1
        WHEN EXTRACT(MONTH FROM dt) IN (10,11,12) THEN 2
        WHEN EXTRACT(MONTH FROM dt) IN (1,2,3)    THEN 3
        ELSE 4
    END::SMALLINT                            AS fiscal_quarter,
    EXTRACT(ISODOW FROM dt) IN (6, 7)        AS is_weekend
FROM generate_series(
    '2020-01-01'::DATE,
    '2030-12-31'::DATE,
    '1 day'::INTERVAL
) AS dt;

-- Verify: Expected 4018 rows
SELECT COUNT(*) AS dim_date_rows FROM warehouse.dim_date;


-- ============================================================
-- STEP 2: LOAD dim_store — SCD TYPE 1
-- Pattern: INSERT ... ON CONFLICT DO UPDATE
-- Changes overwrite existing record — no history retained
-- Unique constraint on store_id is required for ON CONFLICT
-- Source: staging.stores
-- Expected rows: 5
-- ============================================================

INSERT INTO warehouse.dim_store (
    store_id, store_name, city, state,
    region, store_type, manager_name, opening_date
)
SELECT
    store_id,
    name        AS store_name,
    city,
    state,
    region,
    type        AS store_type,
    manager     AS manager_name,
    open_date   AS opening_date
FROM staging.stores
ON CONFLICT (store_id) DO UPDATE SET
    store_name   = EXCLUDED.store_name,
    city         = EXCLUDED.city,
    state        = EXCLUDED.state,
    region       = EXCLUDED.region,
    store_type   = EXCLUDED.store_type,
    manager_name = EXCLUDED.manager_name;

-- Verify: Expected 5 rows
SELECT COUNT(*) AS dim_store_rows FROM warehouse.dim_store;


-- ============================================================
-- STEP 3: LOAD dim_customer — SCD TYPE 2
-- Pattern: CTE with UPDATE ... RETURNING + INSERT
--
-- How it works:
--   Step 3a — source_data CTE:
--     Reads staging.customers, calculates customer_segment
--     from total spend, and builds MD5 hash of tracked columns
--     (name, email, address, city, state)
--
--   Step 3b — expire_changed CTE:
--     Finds existing is_current=TRUE records where hash differs
--     Sets expiry_date = yesterday, is_current = FALSE
--     Returns expired customer_ids via RETURNING
--
--   Step 3c — INSERT:
--     Inserts new records for:
--       a) Brand new customers (no existing record)
--       b) Changed customers (old record just expired)
--
-- Source: staging.customers + staging.orders
-- Expected rows on first load: 10
-- ============================================================

WITH source_data AS (
    SELECT
        c.customer_id,
        c.name          AS customer_name,
        c.email,
        c.phone,
        c.address,
        c.city,
        c.state,
        c.zip           AS zip_code,
        CASE
            WHEN total_spend >= 10000 THEN 'Gold'
            WHEN total_spend >= 5000  THEN 'Silver'
            ELSE 'Bronze'
        END             AS customer_segment,
        decode(
            md5(CONCAT(
                c.name,    '|',
                c.email,   '|',
                c.address, '|',
                c.city,    '|',
                c.state
            )),
            'hex'
        )               AS row_hash
    FROM staging.customers c
    LEFT JOIN (
        SELECT customer_id, SUM(total_amount) AS total_spend
        FROM staging.orders
        GROUP BY customer_id
    ) o ON c.customer_id = o.customer_id
),

expire_changed AS (
    UPDATE warehouse.dim_customer
    SET expiry_date = CURRENT_DATE - INTERVAL '1 day',
        is_current  = FALSE
    FROM source_data s
    WHERE warehouse.dim_customer.customer_id = s.customer_id
      AND warehouse.dim_customer.is_current  = TRUE
      AND warehouse.dim_customer.row_hash   <> s.row_hash
    RETURNING warehouse.dim_customer.customer_id
)

INSERT INTO warehouse.dim_customer (
    customer_id, customer_name, email, phone, address,
    city, state, zip_code, customer_segment,
    effective_date, expiry_date, is_current, row_hash
)
SELECT
    s.customer_id, s.customer_name, s.email, s.phone, s.address,
    s.city, s.state, s.zip_code, s.customer_segment,
    CURRENT_DATE        AS effective_date,
    '9999-12-31'::DATE  AS expiry_date,
    TRUE                AS is_current,
    s.row_hash
FROM source_data s
LEFT JOIN warehouse.dim_customer dc
    ON s.customer_id = dc.customer_id
    AND dc.is_current = TRUE
WHERE dc.customer_key IS NULL;

-- Verify: Expected 10 rows on first load
SELECT COUNT(*) AS dim_customer_rows FROM warehouse.dim_customer;


-- ============================================================
-- STEP 4: LOAD dim_product — SCD TYPE 2
-- Same pattern as dim_customer
-- Tracked columns: name, category, subcategory, brand,
--   cost_price, list_price, supplier_name, supplier_country
-- Supplier attributes denormalised into dim_product
--   to maintain star schema (avoid dim_supplier snowflake)
-- Source: staging.products JOIN staging.suppliers
-- Expected rows on first load: 10
-- ============================================================

WITH source_data AS (
    SELECT
        p.product_id,
        p.name              AS product_name,
        p.category,
        p.subcategory,
        p.brand,
        p.cost              AS cost_price,
        p.list_price,
        s.name              AS supplier_name,
        s.country           AS supplier_country,
        decode(
            md5(CONCAT(
                p.name,             '|',
                p.category,         '|',
                p.subcategory,      '|',
                p.brand,            '|',
                p.cost::TEXT,       '|',
                p.list_price::TEXT, '|',
                COALESCE(s.name,    ''), '|',
                COALESCE(s.country, '')
            )),
            'hex'
        )                   AS row_hash
    FROM staging.products p
    LEFT JOIN staging.suppliers s
        ON p.supplier_id = s.supplier_id
),

expire_changed AS (
    UPDATE warehouse.dim_product
    SET expiry_date = CURRENT_DATE - INTERVAL '1 day',
        is_current  = FALSE
    FROM source_data s
    WHERE warehouse.dim_product.product_id  = s.product_id
      AND warehouse.dim_product.is_current  = TRUE
      AND warehouse.dim_product.row_hash   <> s.row_hash
    RETURNING warehouse.dim_product.product_id
)

INSERT INTO warehouse.dim_product (
    product_id, product_name, category, subcategory, brand,
    cost_price, list_price, supplier_name, supplier_country,
    effective_date, expiry_date, is_current, row_hash
)
SELECT
    s.product_id, s.product_name, s.category, s.subcategory, s.brand,
    s.cost_price, s.list_price, s.supplier_name, s.supplier_country,
    CURRENT_DATE       AS effective_date,
    '9999-12-31'::DATE AS expiry_date,
    TRUE               AS is_current,
    s.row_hash
FROM source_data s
LEFT JOIN warehouse.dim_product dp
    ON s.product_id = dp.product_id
    AND dp.is_current = TRUE
WHERE dp.product_key IS NULL;

-- Verify: Expected 10 rows on first load
SELECT COUNT(*) AS dim_product_rows FROM warehouse.dim_product;


-- ============================================================
-- STEP 5: LOAD dim_promotion — SCD TYPE 1
-- Pattern: INSERT ... ON CONFLICT DO UPDATE
-- Changes overwrite existing record — no history retained
-- Unique constraint on promo_id required for ON CONFLICT
-- Source: staging.promotions
-- Expected rows: 5
-- ============================================================

INSERT INTO warehouse.dim_promotion (
    promo_id, promo_name, promo_type, discount_pct,
    start_date, end_date, channel
)
SELECT
    promo_id,
    name         AS promo_name,
    type         AS promo_type,
    discount_pct,
    start_date,
    end_date,
    channel
FROM staging.promotions
ON CONFLICT (promo_id) DO UPDATE SET
    promo_name   = EXCLUDED.promo_name,
    promo_type   = EXCLUDED.promo_type,
    discount_pct = EXCLUDED.discount_pct,
    start_date   = EXCLUDED.start_date,
    end_date     = EXCLUDED.end_date,
    channel      = EXCLUDED.channel;

-- Verify: Expected 5 rows
SELECT COUNT(*) AS dim_promotion_rows FROM warehouse.dim_promotion;


-- ============================================================
-- STEP 6: LOAD fact_sales
-- Grain: one row per order line item
-- Joins staging tables to warehouse dimensions using
--   is_current=TRUE to get correct surrogate keys
-- promotion_key resolved via discount > 0 check
-- order_line_num generated via ROW_NUMBER window function
-- Source: staging.order_items + staging.orders +
--   all warehouse dimension tables
-- Expected rows: 25
-- ============================================================

INSERT INTO warehouse.fact_sales (
    date_key, customer_key, product_key, store_key, promotion_key,
    order_id, order_line_num, quantity, unit_price, unit_cost,
    discount_amount, net_revenue, gross_profit, tax_amount
)
SELECT
    TO_CHAR(o.order_date, 'YYYYMMDD')::INTEGER  AS date_key,
    dc.customer_key,
    dp.product_key,
    ds.store_key,
    dpr.promotion_key,
    o.order_id,
    ROW_NUMBER() OVER (
        PARTITION BY oi.order_id
        ORDER BY oi.item_id
    )                                            AS order_line_num,
    oi.quantity,
    oi.unit_price,
    p.cost                                       AS unit_cost,
    ROUND((oi.unit_price * oi.quantity * oi.discount / 100), 2)
                                                 AS discount_amount,
    ROUND((oi.unit_price * oi.quantity)
        - (oi.unit_price * oi.quantity * oi.discount / 100), 2)
                                                 AS net_revenue,
    ROUND((oi.unit_price * oi.quantity)
        - (oi.unit_price * oi.quantity * oi.discount / 100)
        - (p.cost * oi.quantity), 2)             AS gross_profit,
    ROUND(((oi.unit_price * oi.quantity)
        - (oi.unit_price * oi.quantity * oi.discount / 100)) * 0.08, 2)
                                                 AS tax_amount
FROM staging.order_items oi
INNER JOIN staging.orders o
    ON oi.order_id = o.order_id
INNER JOIN warehouse.dim_customer dc
    ON o.customer_id = dc.customer_id
    AND dc.is_current = TRUE
INNER JOIN warehouse.dim_product dp
    ON oi.product_id = dp.product_id
    AND dp.is_current = TRUE
INNER JOIN warehouse.dim_store ds
    ON o.store_id = ds.store_id
LEFT JOIN warehouse.dim_promotion dpr
    ON dpr.promo_id = (
        SELECT promo_id
        FROM staging.promotions
        WHERE oi.discount > 0
        LIMIT 1
    )
INNER JOIN staging.products p
    ON oi.product_id = p.product_id;

-- Verify: Expected 25 rows
SELECT COUNT(*) AS fact_sales_rows FROM warehouse.fact_sales;

-- Sanity check on key metrics
SELECT
    COUNT(*)                        AS total_rows,
    COUNT(DISTINCT order_id)        AS distinct_orders,
    COUNT(DISTINCT customer_key)    AS distinct_customers,
    COUNT(DISTINCT product_key)     AS distinct_products,
    COUNT(DISTINCT store_key)       AS distinct_stores,
    ROUND(SUM(net_revenue), 2)      AS total_revenue,
    ROUND(SUM(gross_profit), 2)     AS total_profit
FROM warehouse.fact_sales;
