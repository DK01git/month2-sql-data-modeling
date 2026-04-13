
-- ============================================================
-- SECTION 1: SCHEMAS
-- ============================================================

CREATE SCHEMA IF NOT EXISTS warehouse;
CREATE SCHEMA IF NOT EXISTS staging;


-- ============================================================
-- SECTION 2: OLTP SOURCE TABLES (public schema)
-- These represent the operational source system
-- Load order respects FK dependencies:
-- suppliers → products → customers → stores →
-- promotions → orders → order_items → inventory
-- ============================================================

CREATE TABLE IF NOT EXISTS public.suppliers (
    supplier_id     VARCHAR(20) PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    contact         VARCHAR(100),
    country         VARCHAR(50),
    lead_time_days  INTEGER
);

CREATE TABLE IF NOT EXISTS public.products (
    product_id      VARCHAR(20) PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    category        VARCHAR(50) NOT NULL,
    subcategory     VARCHAR(50),
    brand           VARCHAR(50),
    cost            NUMERIC(10,2),
    list_price      NUMERIC(10,2),
    supplier_id     VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS public.customers (
    customer_id     VARCHAR(20) PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    email           VARCHAR(100),
    phone           VARCHAR(20),
    address         VARCHAR(200),
    city            VARCHAR(50),
    state           VARCHAR(2),
    zip             VARCHAR(10),
    created_date    DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS public.stores (
    store_id        VARCHAR(20) PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    city            VARCHAR(50),
    state           VARCHAR(2),
    region          VARCHAR(20),
    type            VARCHAR(20),
    manager         VARCHAR(100),
    open_date       DATE
);

CREATE TABLE IF NOT EXISTS public.promotions (
    promo_id        VARCHAR(20) PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    type            VARCHAR(50),
    discount_pct    NUMERIC(5,2),
    start_date      DATE,
    end_date        DATE,
    channel         VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS public.orders (
    order_id        VARCHAR(20) PRIMARY KEY,
    customer_id     VARCHAR(20) NOT NULL,
    order_date      DATE NOT NULL,
    status          VARCHAR(20) NOT NULL,
    total_amount    NUMERIC(12,2) NOT NULL,
    store_id        VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS public.order_items (
    item_id         VARCHAR(20) PRIMARY KEY,
    order_id        VARCHAR(20) NOT NULL REFERENCES public.orders(order_id),
    product_id      VARCHAR(20) NOT NULL,
    quantity        INTEGER NOT NULL,
    unit_price      NUMERIC(10,2) NOT NULL,
    discount        NUMERIC(5,2) DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.inventory (
    store_id            VARCHAR(20) NOT NULL REFERENCES public.stores(store_id),
    product_id          VARCHAR(20) NOT NULL REFERENCES public.products(product_id),
    quantity_on_hand    INTEGER NOT NULL,
    reorder_point       INTEGER NOT NULL,
    last_restock_date   DATE,
    PRIMARY KEY (store_id, product_id)
);


-- ============================================================
-- SECTION 3: STAGING MIRROR TABLES (staging schema)
-- Direct mirrors of public OLTP tables
-- Used as source for SCD load scripts
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.suppliers (
    supplier_id     VARCHAR(20) PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    contact         VARCHAR(100),
    country         VARCHAR(50),
    lead_time_days  INTEGER
);

CREATE TABLE IF NOT EXISTS staging.products (
    product_id      VARCHAR(20) PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    category        VARCHAR(50) NOT NULL,
    subcategory     VARCHAR(50),
    brand           VARCHAR(50),
    cost            NUMERIC(10,2),
    list_price      NUMERIC(10,2),
    supplier_id     VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS staging.customers (
    customer_id     VARCHAR(20) PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    email           VARCHAR(100),
    phone           VARCHAR(20),
    address         VARCHAR(200),
    city            VARCHAR(50),
    state           VARCHAR(2),
    zip             VARCHAR(10),
    created_date    DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS staging.stores (
    store_id        VARCHAR(20) PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    city            VARCHAR(50),
    state           VARCHAR(2),
    region          VARCHAR(20),
    type            VARCHAR(20),
    manager         VARCHAR(100),
    open_date       DATE
);

CREATE TABLE IF NOT EXISTS staging.promotions (
    promo_id        VARCHAR(20) PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    type            VARCHAR(50),
    discount_pct    NUMERIC(5,2),
    start_date      DATE,
    end_date        DATE,
    channel         VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS staging.orders (
    order_id        VARCHAR(20) PRIMARY KEY,
    customer_id     VARCHAR(20) NOT NULL,
    order_date      DATE NOT NULL,
    status          VARCHAR(20) NOT NULL,
    total_amount    NUMERIC(12,2) NOT NULL,
    store_id        VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS staging.order_items (
    item_id         VARCHAR(20) PRIMARY KEY,
    order_id        VARCHAR(20) NOT NULL,
    product_id      VARCHAR(20) NOT NULL,
    quantity        INTEGER NOT NULL,
    unit_price      NUMERIC(10,2) NOT NULL,
    discount        NUMERIC(5,2) DEFAULT 0
);

CREATE TABLE IF NOT EXISTS staging.inventory (
    store_id            VARCHAR(20) NOT NULL,
    product_id          VARCHAR(20) NOT NULL,
    quantity_on_hand    INTEGER NOT NULL,
    reorder_point       INTEGER NOT NULL,
    last_restock_date   DATE,
    PRIMARY KEY (store_id, product_id)
);


-- ============================================================
-- SECTION 4: WAREHOUSE DIMENSIONAL MODEL (warehouse schema)
-- Star schema following Kimball methodology
-- Table creation order respects FK dependencies:
-- dim_date → dim_customer → dim_product →
-- dim_store → dim_promotion → fact_sales
-- ============================================================

-- Date Dimension
-- Generated for 2020-2030, no source table
-- Primary key is integer in YYYYMMDD format
CREATE TABLE IF NOT EXISTS warehouse.dim_date (
    date_key        INTEGER NOT NULL PRIMARY KEY,
    full_date       DATE NOT NULL,
    day_of_week     SMALLINT NOT NULL,
    day_name        VARCHAR(10) NOT NULL,
    day_of_month    SMALLINT NOT NULL,
    day_of_year     SMALLINT NOT NULL,
    week_of_year    SMALLINT NOT NULL,
    month_number    SMALLINT NOT NULL,
    month_name      VARCHAR(10) NOT NULL,
    quarter_number  SMALLINT NOT NULL,
    quarter_name    VARCHAR(6) NOT NULL,
    year_number     SMALLINT NOT NULL,
    fiscal_year     SMALLINT NOT NULL,
    fiscal_quarter  SMALLINT NOT NULL,
    is_weekend      BOOLEAN NOT NULL,
    is_holiday      BOOLEAN NOT NULL DEFAULT FALSE,
    holiday_name    VARCHAR(50) NULL
);

-- Customer Dimension — SCD Type 2
-- New version created on: name, email, address, city, state changes
-- is_current=TRUE identifies active record
CREATE TABLE IF NOT EXISTS warehouse.dim_customer (
    customer_key        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id         VARCHAR(20) NOT NULL,
    customer_name       VARCHAR(100) NOT NULL,
    email               VARCHAR(100),
    phone               VARCHAR(20),
    address             VARCHAR(200),
    city                VARCHAR(50),
    state               VARCHAR(2),
    zip_code            VARCHAR(10),
    customer_segment    VARCHAR(20),
    effective_date      DATE NOT NULL,
    expiry_date         DATE NOT NULL DEFAULT '9999-12-31',
    is_current          BOOLEAN NOT NULL DEFAULT TRUE,
    row_hash            BYTEA
);

-- Product Dimension — SCD Type 2
-- New version created on: name, category, subcategory, brand,
-- cost_price, list_price, supplier_name, supplier_country changes
-- Supplier attributes denormalised into this table (star schema design)
CREATE TABLE IF NOT EXISTS warehouse.dim_product (
    product_key         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id          VARCHAR(20) NOT NULL,
    product_name        VARCHAR(200) NOT NULL,
    category            VARCHAR(50) NOT NULL,
    subcategory         VARCHAR(50),
    brand               VARCHAR(50),
    cost_price          NUMERIC(10,2),
    list_price          NUMERIC(10,2),
    supplier_name       VARCHAR(100),
    supplier_country    VARCHAR(50),
    effective_date      DATE NOT NULL,
    expiry_date         DATE NOT NULL DEFAULT '9999-12-31',
    is_current          BOOLEAN NOT NULL DEFAULT TRUE,
    row_hash            BYTEA
);

-- Store Dimension — SCD Type 1
-- Changes overwrite existing record — no history retained
-- UNIQUE constraint on store_id required for ON CONFLICT upsert
CREATE TABLE IF NOT EXISTS warehouse.dim_store (
    store_key       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    store_id        VARCHAR(20) NOT NULL,
    store_name      VARCHAR(100) NOT NULL,
    city            VARCHAR(50),
    state           VARCHAR(2),
    region          VARCHAR(20),
    store_type      VARCHAR(20),
    manager_name    VARCHAR(100),
    opening_date    DATE
);

ALTER TABLE warehouse.dim_store
    ADD CONSTRAINT uq_dim_store_store_id UNIQUE (store_id);

-- Promotion Dimension — SCD Type 1
-- Changes overwrite existing record — no history retained
-- UNIQUE constraint on promo_id required for ON CONFLICT upsert
-- promotion_key is nullable in fact_sales — not every sale has a promotion
CREATE TABLE IF NOT EXISTS warehouse.dim_promotion (
    promotion_key   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    promo_id        VARCHAR(20) NOT NULL,
    promo_name      VARCHAR(100) NOT NULL,
    promo_type      VARCHAR(50),
    discount_pct    NUMERIC(5,2),
    start_date      DATE,
    end_date        DATE,
    channel         VARCHAR(50)
);

ALTER TABLE warehouse.dim_promotion
    ADD CONSTRAINT uq_dim_promotion_promo_id UNIQUE (promo_id);

-- Fact Sales Table
-- Grain: one row per order line item
-- All dimension FKs except promotion_key are NOT NULL
-- promotion_key is nullable — not every sale has a promotion
CREATE TABLE IF NOT EXISTS warehouse.fact_sales (
    sales_key       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_key        INTEGER NOT NULL REFERENCES warehouse.dim_date(date_key),
    customer_key    INTEGER NOT NULL REFERENCES warehouse.dim_customer(customer_key),
    product_key     INTEGER NOT NULL REFERENCES warehouse.dim_product(product_key),
    store_key       INTEGER NOT NULL REFERENCES warehouse.dim_store(store_key),
    promotion_key   INTEGER REFERENCES warehouse.dim_promotion(promotion_key),
    order_id        VARCHAR(20) NOT NULL,
    order_line_num  INTEGER NOT NULL,
    quantity        INTEGER NOT NULL,
    unit_price      NUMERIC(10,2) NOT NULL,
    unit_cost       NUMERIC(10,2) NOT NULL,
    discount_amount NUMERIC(10,2) DEFAULT 0,
    net_revenue     NUMERIC(12,2) NOT NULL,
    gross_profit    NUMERIC(12,2) NOT NULL,
    tax_amount      NUMERIC(10,2) DEFAULT 0
);

-- Indexes on fact_sales foreign keys
-- Critical for query performance on large datasets
CREATE INDEX ix_fact_sales_date     ON warehouse.fact_sales(date_key);
CREATE INDEX ix_fact_sales_customer ON warehouse.fact_sales(customer_key);
CREATE INDEX ix_fact_sales_product  ON warehouse.fact_sales(product_key);
CREATE INDEX ix_fact_sales_store    ON warehouse.fact_sales(store_key);


-- ============================================================
-- VERIFICATION QUERIES
-- Run after executing all DDL to confirm structure
-- ============================================================

-- Confirm all tables exist across all schemas
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('public', 'staging', 'warehouse')
ORDER BY table_schema, table_name;

-- Confirm indexes on fact_sales
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'fact_sales'
AND schemaname = 'warehouse';
