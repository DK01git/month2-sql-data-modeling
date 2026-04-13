-- ============================================================
--
-- QUERY INDEX:
--   Q01 — Monthly Sales Trend with Running Total
--   Q02 — Product Category Ranking by Region
--   Q03 — Customer Cohort Analysis
--   Q04 — Top Customers by Revenue with Ranking
--   Q05 — Store Performance vs Average
--   Q06 — Product Profit Margin Analysis
--   Q07 — Weekly Sales with 4-Week Moving Average
--   Q08 — Customer Segment Revenue Contribution
--   Q09 — Promotion Effectiveness Analysis
--   Q10 — Product Category Quarterly Growth
--   Q11 — RFM Customer Analysis
-- ============================================================


-- ============================================================
-- Q01: Monthly Sales Trend with Running Total
-- Techniques: SUM window function, LAG, running total,
--             MoM growth percentage, NULLIF for safe division
-- Business use: Track revenue momentum month over month
-- ============================================================

SELECT
    d.year_number,
    d.month_name,
    SUM(f.net_revenue)                                          AS monthly_revenue,
    SUM(SUM(f.net_revenue)) OVER (
        PARTITION BY d.year_number
        ORDER BY d.month_number
    )                                                           AS ytd_revenue,
    LAG(SUM(f.net_revenue)) OVER (
        ORDER BY d.year_number, d.month_number
    )                                                           AS prev_month_revenue,
    ROUND(
        (SUM(f.net_revenue) - LAG(SUM(f.net_revenue)) OVER (
            ORDER BY d.year_number, d.month_number)
        ) / NULLIF(LAG(SUM(f.net_revenue)) OVER (
            ORDER BY d.year_number, d.month_number), 0) * 100
    , 2)                                                        AS mom_growth_pct
FROM warehouse.fact_sales f
JOIN warehouse.dim_date d ON f.date_key = d.date_key
GROUP BY d.year_number, d.month_number, d.month_name
ORDER BY d.year_number, d.month_number;


-- ============================================================
-- Q02: Product Category Ranking by Region
-- Techniques: CTE, RANK window function partitioned by region,
--             multi-table join, filtered output
-- Business use: Identify top-performing categories per region
-- ============================================================

WITH category_revenue AS (
    SELECT
        s.region,
        p.category,
        SUM(f.net_revenue)                                      AS total_revenue,
        RANK() OVER (
            PARTITION BY s.region
            ORDER BY SUM(f.net_revenue) DESC
        )                                                       AS category_rank
    FROM warehouse.fact_sales f
    JOIN warehouse.dim_product p ON f.product_key = p.product_key
    JOIN warehouse.dim_store s   ON f.store_key   = s.store_key
    WHERE p.is_current = TRUE
    GROUP BY s.region, p.category
)
SELECT region, category, total_revenue, category_rank
FROM category_revenue
WHERE category_rank <= 5
ORDER BY region, category_rank;


-- ============================================================
-- Q03: Customer Cohort Analysis
-- Techniques: CTE, DATE_TRUNC, AGE function, cohort month
--             calculation, multi-level grouping
-- Business use: Understand customer retention by acquisition month
-- ============================================================

WITH first_purchase AS (
    SELECT
        f.customer_key,
        MIN(d.full_date)                                        AS first_purchase_date,
        DATE_TRUNC('month', MIN(d.full_date))::DATE             AS cohort_month
    FROM warehouse.fact_sales f
    JOIN warehouse.dim_date d ON f.date_key = d.date_key
    GROUP BY f.customer_key
)
SELECT
    fp.cohort_month,
    EXTRACT(YEAR FROM AGE(
        DATE_TRUNC('month', d.full_date), fp.cohort_month)
    ) * 12
    + EXTRACT(MONTH FROM AGE(
        DATE_TRUNC('month', d.full_date), fp.cohort_month)
    )                                                           AS months_since_first,
    COUNT(DISTINCT f.customer_key)                              AS active_customers,
    SUM(f.net_revenue)                                          AS cohort_revenue
FROM warehouse.fact_sales f
JOIN warehouse.dim_date d       ON f.date_key     = d.date_key
JOIN first_purchase fp          ON f.customer_key = fp.customer_key
GROUP BY fp.cohort_month,
    EXTRACT(YEAR FROM AGE(
        DATE_TRUNC('month', d.full_date), fp.cohort_month)
    ) * 12
    + EXTRACT(MONTH FROM AGE(
        DATE_TRUNC('month', d.full_date), fp.cohort_month)
    )
ORDER BY fp.cohort_month, months_since_first;


-- ============================================================
-- Q04: Top Customers by Revenue with Ranking
-- Techniques: RANK window function, aggregation,
--             multi-column grouping, AVG order value
-- Business use: Identify highest-value customers for
--               loyalty programmes and targeted campaigns
-- ============================================================

SELECT
    dc.customer_name,
    dc.customer_segment,
    dc.city,
    dc.state,
    COUNT(DISTINCT f.order_id)              AS total_orders,
    SUM(f.quantity)                         AS total_items,
    ROUND(SUM(f.net_revenue), 2)            AS total_revenue,
    ROUND(AVG(f.net_revenue), 2)            AS avg_order_value,
    RANK() OVER (
        ORDER BY SUM(f.net_revenue) DESC
    )                                       AS revenue_rank
FROM warehouse.fact_sales f
JOIN warehouse.dim_customer dc
    ON f.customer_key = dc.customer_key
    AND dc.is_current = TRUE
GROUP BY
    dc.customer_name, dc.customer_segment,
    dc.city, dc.state
ORDER BY revenue_rank;


-- ============================================================
-- Q05: Store Performance vs Company Average
-- Techniques: Window function without partition (global avg),
--             deviation calculation, RANK
-- Business use: Identify underperforming and overperforming
--               stores against company benchmark
-- ============================================================

WITH store_revenue AS (
    SELECT
        ds.store_name,
        ds.region,
        ds.store_type,
        ROUND(SUM(f.net_revenue), 2)        AS total_revenue,
        COUNT(DISTINCT f.order_id)          AS total_orders,
        ROUND(AVG(f.net_revenue), 2)        AS avg_order_value
    FROM warehouse.fact_sales f
    JOIN warehouse.dim_store ds ON f.store_key = ds.store_key
    GROUP BY ds.store_name, ds.region, ds.store_type
)
SELECT
    store_name,
    region,
    store_type,
    total_revenue,
    total_orders,
    avg_order_value,
    ROUND(AVG(total_revenue) OVER (), 2)    AS avg_store_revenue,
    ROUND(total_revenue
        - AVG(total_revenue) OVER (), 2)    AS deviation_from_avg,
    RANK() OVER (
        ORDER BY total_revenue DESC
    )                                       AS store_rank
FROM store_revenue
ORDER BY store_rank;


-- ============================================================
-- Q06: Product Profit Margin Analysis
-- Techniques: Dual RANK (by margin + by revenue),
--             NULLIF for safe division, derived metrics
-- Business use: Identify high-margin vs high-volume products
--               to optimise product mix decisions
-- ============================================================

WITH product_metrics AS (
    SELECT
        dp.product_name,
        dp.category,
        dp.brand,
        SUM(f.quantity)                     AS units_sold,
        ROUND(SUM(f.net_revenue), 2)        AS total_revenue,
        ROUND(SUM(f.gross_profit), 2)       AS total_profit,
        ROUND(SUM(f.discount_amount), 2)    AS total_discount,
        ROUND(
            SUM(f.gross_profit) /
            NULLIF(SUM(f.net_revenue), 0) * 100
        , 2)                                AS profit_margin_pct
    FROM warehouse.fact_sales f
    JOIN warehouse.dim_product dp
        ON f.product_key = dp.product_key
        AND dp.is_current = TRUE
    GROUP BY dp.product_name, dp.category, dp.brand
)
SELECT
    product_name,
    category,
    brand,
    units_sold,
    total_revenue,
    total_profit,
    total_discount,
    profit_margin_pct,
    RANK() OVER (
        ORDER BY profit_margin_pct DESC
    )                                       AS margin_rank,
    RANK() OVER (
        ORDER BY total_revenue DESC
    )                                       AS revenue_rank
FROM product_metrics
ORDER BY revenue_rank;


-- ============================================================
-- Q07: Weekly Sales with 4-Week Moving Average
-- Techniques: ROWS BETWEEN frame clause, moving average,
--             YTD running total partitioned by year
-- Business use: Smooth out weekly volatility to identify
--               true sales trends
-- ============================================================

WITH weekly_sales AS (
    SELECT
        d.year_number,
        d.week_of_year,
        MIN(d.full_date)                    AS week_start,
        ROUND(SUM(f.net_revenue), 2)        AS weekly_revenue,
        COUNT(DISTINCT f.order_id)          AS weekly_orders
    FROM warehouse.fact_sales f
    JOIN warehouse.dim_date d ON f.date_key = d.date_key
    GROUP BY d.year_number, d.week_of_year
)
SELECT
    week_start,
    weekly_revenue,
    weekly_orders,
    ROUND(AVG(weekly_revenue) OVER (
        ORDER BY year_number, week_of_year
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    ), 2)                                   AS moving_avg_4week,
    ROUND(SUM(weekly_revenue) OVER (
        PARTITION BY year_number
        ORDER BY week_of_year
    ), 2)                                   AS ytd_revenue
FROM weekly_sales
ORDER BY week_start;


-- ============================================================
-- Q08: Customer Segment Revenue Contribution
-- Techniques: SUM window function without partition,
--             percentage contribution calculation
-- Business use: Understand revenue and profit split
--               across customer value segments
-- ============================================================

WITH segment_metrics AS (
    SELECT
        dc.customer_segment,
        COUNT(DISTINCT f.customer_key)      AS customer_count,
        COUNT(DISTINCT f.order_id)          AS total_orders,
        ROUND(SUM(f.net_revenue), 2)        AS total_revenue,
        ROUND(AVG(f.net_revenue), 2)        AS avg_order_value,
        ROUND(SUM(f.gross_profit), 2)       AS total_profit
    FROM warehouse.fact_sales f
    JOIN warehouse.dim_customer dc
        ON f.customer_key = dc.customer_key
        AND dc.is_current = TRUE
    GROUP BY dc.customer_segment
)
SELECT
    customer_segment,
    customer_count,
    total_orders,
    total_revenue,
    avg_order_value,
    total_profit,
    ROUND(
        total_revenue /
        SUM(total_revenue) OVER () * 100
    , 2)                                    AS revenue_contribution_pct,
    ROUND(
        total_profit /
        SUM(total_profit) OVER () * 100
    , 2)                                    AS profit_contribution_pct
FROM segment_metrics
ORDER BY total_revenue DESC;


-- ============================================================
-- Q09: Promotion Effectiveness Analysis
-- Techniques: LEFT JOIN to include non-promoted sales,
--             COALESCE for null handling, revenue share %
-- Business use: Compare revenue and profit from promoted
--               vs non-promoted sales
-- ============================================================

WITH promo_metrics AS (
    SELECT
        COALESCE(dp.promo_name, 'No Promotion') AS promotion,
        COALESCE(dp.promo_type, 'N/A')          AS promo_type,
        COUNT(DISTINCT f.order_id)              AS total_orders,
        SUM(f.quantity)                         AS units_sold,
        ROUND(SUM(f.discount_amount), 2)        AS total_discount_given,
        ROUND(SUM(f.net_revenue), 2)            AS total_revenue,
        ROUND(SUM(f.gross_profit), 2)           AS total_profit,
        ROUND(AVG(f.discount_amount), 2)        AS avg_discount_per_order
    FROM warehouse.fact_sales f
    LEFT JOIN warehouse.dim_promotion dp
        ON f.promotion_key = dp.promotion_key
    GROUP BY dp.promo_name, dp.promo_type
)
SELECT
    promotion,
    promo_type,
    total_orders,
    units_sold,
    total_discount_given,
    total_revenue,
    total_profit,
    avg_discount_per_order,
    ROUND(
        total_revenue /
        SUM(total_revenue) OVER () * 100
    , 2)                                        AS revenue_share_pct
FROM promo_metrics
ORDER BY total_revenue DESC;


-- ============================================================
-- Q10: Product Category Quarterly Growth
-- Techniques: LAG partitioned by category,
--             QoQ growth percentage, NULLIF safe division
-- Business use: Track which categories are growing or
--               declining each quarter
-- ============================================================

WITH quarterly_category AS (
    SELECT
        d.year_number,
        d.quarter_name,
        d.quarter_number,
        p.category,
        ROUND(SUM(f.net_revenue), 2)        AS quarterly_revenue,
        SUM(f.quantity)                     AS units_sold
    FROM warehouse.fact_sales f
    JOIN warehouse.dim_date d    ON f.date_key    = d.date_key
    JOIN warehouse.dim_product p ON f.product_key = p.product_key
        AND p.is_current = TRUE
    GROUP BY
        d.year_number, d.quarter_number,
        d.quarter_name, p.category
)
SELECT
    year_number,
    quarter_name,
    category,
    quarterly_revenue,
    units_sold,
    LAG(quarterly_revenue) OVER (
        PARTITION BY category
        ORDER BY year_number, quarter_number
    )                                       AS prev_quarter_revenue,
    ROUND(
        (quarterly_revenue - LAG(quarterly_revenue) OVER (
            PARTITION BY category
            ORDER BY year_number, quarter_number)
        ) / NULLIF(LAG(quarterly_revenue) OVER (
            PARTITION BY category
            ORDER BY year_number, quarter_number), 0) * 100
    , 2)                                    AS qoq_growth_pct
FROM quarterly_category
ORDER BY year_number, quarter_number, category;


-- ============================================================
-- Q11: RFM Customer Analysis (Recency, Frequency, Monetary)
-- Techniques: NTILE window function for scoring,
--             CURRENT_DATE arithmetic for recency,
--             three-dimensional customer scoring
-- Business use: Score customers across three dimensions
--               to identify best and at-risk customers
--   Recency  score 1 = most recent purchaser
--   Frequency score 1 = most frequent purchaser
--   Monetary  score 1 = highest spender
-- ============================================================

WITH rfm_base AS (
    SELECT
        dc.customer_name,
        dc.customer_segment,
        COUNT(DISTINCT f.order_id)              AS frequency,
        ROUND(SUM(f.net_revenue), 2)            AS monetary,
        MAX(d.full_date)                        AS last_purchase_date,
        CURRENT_DATE - MAX(d.full_date)         AS days_since_last_purchase
    FROM warehouse.fact_sales f
    JOIN warehouse.dim_customer dc
        ON f.customer_key = dc.customer_key
        AND dc.is_current = TRUE
    JOIN warehouse.dim_date d ON f.date_key = d.date_key
    GROUP BY dc.customer_name, dc.customer_segment
)
SELECT
    customer_name,
    customer_segment,
    frequency,
    monetary,
    last_purchase_date,
    days_since_last_purchase,
    NTILE(3) OVER (
        ORDER BY days_since_last_purchase ASC
    )                                           AS recency_score,
    NTILE(3) OVER (
        ORDER BY frequency DESC
    )                                           AS frequency_score,
    NTILE(3) OVER (
        ORDER BY monetary DESC
    )                                           AS monetary_score
FROM rfm_base
ORDER BY monetary DESC;
