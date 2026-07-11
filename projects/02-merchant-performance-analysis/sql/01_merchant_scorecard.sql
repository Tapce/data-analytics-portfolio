-- ============================================================================
-- Project 02 - Merchant Performance & Forecasting
-- File: 01_merchant_scorecard.sql
-- Author: Blessed Tapiwa Dongo
-- Purpose: Latest-month performance scorecard per merchant with MoM and YoY
--          movement - the table a weekly performance review starts from.
--
-- Schema (see data/sample/):
--   merchants(merchant_id, merchant_name, sector, onboarded_month,
--             churn_month, status)
--   monthly_metrics(merchant_id, month, txn_count, txn_value_gbp,
--                   declined_count, fee_revenue_gbp)
-- ============================================================================

WITH metrics AS (
    SELECT
        mm.merchant_id,
        m.merchant_name,
        m.sector,
        mm.month,
        mm.txn_count,
        mm.txn_value_gbp,
        mm.fee_revenue_gbp,
        mm.txn_value_gbp / NULLIF(mm.txn_count, 0)                  AS atv,
        100.0 * mm.declined_count
              / NULLIF(mm.txn_count + mm.declined_count, 0)         AS decline_pct,
        LAG(mm.txn_value_gbp, 1)  OVER w                            AS value_prev_m,
        LAG(mm.txn_value_gbp, 12) OVER w                            AS value_prev_y
    FROM monthly_metrics mm
    JOIN merchants m USING (merchant_id)
    WHERE m.status = 'Active'
    WINDOW w AS (PARTITION BY mm.merchant_id ORDER BY mm.month)
)

SELECT
    merchant_id,
    merchant_name,
    sector,
    txn_count,
    ROUND(txn_value_gbp, 0)                                        AS value_gbp,
    ROUND(fee_revenue_gbp, 0)                                      AS fee_gbp,
    ROUND(atv, 2)                                                  AS atv_gbp,
    ROUND(decline_pct, 1)                                          AS decline_pct,
    ROUND(100.0 * (txn_value_gbp - value_prev_m)
                / NULLIF(value_prev_m, 0), 1)                      AS value_mom_pct,
    ROUND(100.0 * (txn_value_gbp - value_prev_y)
                / NULLIF(value_prev_y, 0), 1)                      AS value_yoy_pct
FROM metrics
WHERE month = '2026-06'
ORDER BY fee_revenue_gbp DESC
LIMIT 20;
