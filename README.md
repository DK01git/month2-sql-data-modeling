# RetailCo Analytical Data Warehouse

---

## Overview

This project implements an analytical data warehouse for RetailCo — a multi-channel retail company. It transforms a normalised OLTP source system (8 tables) into a star schema dimensional model optimised for sales analytics and reporting.

```
public schema (OLTP source)
    → staging schema  (mirrors for SCD load scripts)
    → warehouse schema (star schema dimensional model)
```

## Prerequisites

| Tool              | Version   | Purpose                        |
| ----------------- | --------- | ------------------------------ |
| Docker Desktop    | Latest    | Runs PostgreSQL container      |
| DBeaver Community | Latest    | SQL client for running scripts |
| PostgreSQL        | 16-alpine | Database (via Docker)          |

---

## Quick Start

### Step 1 — Start Docker Desktop

Open Docker Desktop and wait for it to show **"Docker Desktop is running"** in the system tray.

### Step 2 — Start the PostgreSQL container

If you completed Month 1, your container already exists. Start it:

```bash
cd C:\de-training\month1
docker compose up -d postgres-retail
```

Verify running:

```bash
docker ps --filter "name=month1-postgres-retail-1"
```

Expected output:

```
STATUS: Up X seconds (healthy)
PORTS:  0.0.0.0:5432->5432/tcp
```

### Step 3 — Connect DBeaver to PostgreSQL

Open DBeaver → New Connection → PostgreSQL:

| Field    | Value     |
| -------- | --------- |
| Host     | localhost |
| Port     | 5432      |
| Database | retailco  |
| Username | retailco  |
| Password | retailco  |

Click **Test Connection** — it should show **Connected**.

### Step 4 — Run the scripts in order

Open each file in DBeaver SQL Editor and run them in this exact order:

| Order | File                                            | Purpose                                           |
| ----- | ----------------------------------------------- | ------------------------------------------------- |
| 1     | `diluksha-perera-month2-ddl-scripts.sql`        | Creates all schemas and tables                    |
| 2     | `sample-data.sql`                               | Loads sample data into public + staging           |
| 3     | `diluksha-perera-month2-scd-implementation.sql` | Loads all warehouse dimension tables + fact_sales |
| 4     | `diluksha-perera-month2-analytical-queries.sql` | Run any query to verify the model works           |

> **Important:** Always run scripts in this order. Each step depends on the previous one completing successfully.

---

## Architecture

### Three-Layer Design

| Layer     | Schema      | Purpose                                             |
| --------- | ----------- | --------------------------------------------------- |
| Source    | `public`    | 8 normalised OLTP tables                            |
| Staging   | `staging`   | Mirrors of source tables — used by SCD load scripts |
| Warehouse | `warehouse` | Star schema dimensional model — analytical layer    |

### Star Schema

`fact_sales` sits at the centre connected to 5 dimension tables:

```
dim_date ──────────┐
dim_customer ──────┤
dim_product ───────► fact_sales
dim_store ─────────┤
dim_promotion ─────┘ (nullable — not every sale has a promotion)
```

### SCD Strategy

| Dimension       | SCD Type | Reason                                                       |
| --------------- | -------- | ------------------------------------------------------------ |
| `dim_customer`  | Type 2   | Customer address and segment changes require history         |
| `dim_product`   | Type 2   | Price and category changes affect historical profit analysis |
| `dim_store`     | Type 1   | Store manager changes do not require history                 |
| `dim_promotion` | Type 1   | Promotion updates do not require history                     |
| `dim_date`      | N/A      | Generated — immutable                                        |

### Indexes

Four indexes on `fact_sales` foreign keys for query performance:

```sql
ix_fact_sales_date      ON fact_sales(date_key)
ix_fact_sales_customer  ON fact_sales(customer_key)
ix_fact_sales_product   ON fact_sales(product_key)
ix_fact_sales_store     ON fact_sales(store_key)
```

---

## Analytical Queries

11 queries demonstrating advanced SQL patterns:

| Query                              | Pattern                         |
| ---------------------------------- | ------------------------------- |
| Q01 — Monthly Sales Trend          | Running total, LAG, MoM growth  |
| Q02 — Category Ranking by Region   | CTE, RANK partitioned by region |
| Q03 — Customer Cohort Analysis     | DATE_TRUNC, AGE, cohort month   |
| Q04 — Top Customers by Revenue     | RANK, aggregation               |
| Q05 — Store Performance vs Average | Deviation from global average   |
| Q06 — Product Profit Margin        | Dual RANK, margin calculation   |
| Q07 — Weekly Moving Average        | ROWS BETWEEN frame clause       |
| Q08 — Segment Revenue Contribution | Percentage of total window      |
| Q09 — Promotion Effectiveness      | LEFT JOIN, COALESCE             |
| Q10 — Quarterly Category Growth    | LAG partitioned by category     |
| Q11 — RFM Customer Scoring         | NTILE across three dimensions   |

---

## Troubleshooting

### Docker container not starting

### ON CONFLICT error on dim_store or dim_promotion load

---

## Service Credentials

| Service    | Host      | Port | Database | Username | Password |
| ---------- | --------- | ---- | -------- | -------- | -------- |
| PostgreSQL | localhost | 5432 | retailco | retailco | retailco |
