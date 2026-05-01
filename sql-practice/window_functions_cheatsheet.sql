-- ============================================================================
-- SQL Practice - Window Functions Cheat Sheet
-- ============================================================================
-- Patterns I reach for repeatedly in operational and merchant analytics.
-- All examples assume a table called sales(sale_date, region, rep, amount).

-- 1. Running total by region (ordered by date)
SELECT
    sale_date, region, rep, amount,
    SUM(amount) OVER (PARTITION BY region ORDER BY sale_date) AS region_running_total
FROM sales;

-- 2. Rank reps within each region by total sales
SELECT
    region, rep, SUM(amount) AS total_amount,
    RANK() OVER (PARTITION BY region ORDER BY SUM(amount) DESC) AS region_rank
FROM sales
GROUP BY region, rep;

-- 3. Month-over-month change
SELECT
    DATE_TRUNC('month', sale_date) AS month,
    SUM(amount) AS month_total,
    LAG(SUM(amount)) OVER (ORDER BY DATE_TRUNC('month', sale_date)) AS prev_month,
    SUM(amount) - LAG(SUM(amount)) OVER (ORDER BY DATE_TRUNC('month', sale_date)) AS mom_change
FROM sales
GROUP BY DATE_TRUNC('month', sale_date);

-- 4. 7-day moving average
SELECT
    sale_date,
    SUM(amount) AS daily_total,
    AVG(SUM(amount)) OVER (
        ORDER BY sale_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS rolling_7d_avg
FROM sales
GROUP BY sale_date;

-- 5. First and last sale per rep (using ROW_NUMBER)
WITH ordered AS (
    SELECT
        rep, sale_date, amount,
        ROW_NUMBER() OVER (PARTITION BY rep ORDER BY sale_date ASC)  AS first_rn,
        ROW_NUMBER() OVER (PARTITION BY rep ORDER BY sale_date DESC) AS last_rn
    FROM sales
)
SELECT
    rep,
    MAX(CASE WHEN first_rn = 1 THEN sale_date END) AS first_sale,
    MAX(CASE WHEN last_rn  = 1 THEN sale_date END) AS last_sale
FROM ordered
GROUP BY rep;
