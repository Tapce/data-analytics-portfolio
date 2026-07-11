-- ============================================================================
-- Project 02 - Merchant Performance & Forecasting
-- File: 04_revenue_concentration.sql
-- Author: Blessed Tapiwa Dongo
-- Purpose: How concentrated is fee revenue? Cumulative share of the last
--          12 months' fee revenue by merchant rank - the exposure question
--          behind every "at risk" conversation.
-- ============================================================================

WITH last12 AS (
    SELECT merchant_id, SUM(fee_revenue_gbp) AS fee_12m
    FROM monthly_metrics
    WHERE month >= '2025-07'
    GROUP BY merchant_id
),

ranked AS (
    SELECT
        merchant_id,
        fee_12m,
        ROW_NUMBER() OVER (ORDER BY fee_12m DESC)        AS rnk,
        SUM(fee_12m) OVER ()                             AS total,
        SUM(fee_12m) OVER (ORDER BY fee_12m DESC)        AS running
    FROM last12
)

SELECT
    rnk                                                  AS top_n,
    m.merchant_name,
    m.sector,
    ROUND(fee_12m, 0)                                    AS fee_12m_gbp,
    ROUND(100.0 * fee_12m / total, 1)                    AS share_pct,
    ROUND(100.0 * running / total, 1)                    AS cumulative_pct
FROM ranked
JOIN merchants m USING (merchant_id)
WHERE rnk <= 20
ORDER BY rnk;
