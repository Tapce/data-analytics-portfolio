-- ============================================================================
-- Project 02 - Merchant Performance & Forecasting
-- File: 02_decline_early_warning.sql
-- Author: Blessed Tapiwa Dongo
-- Purpose: Early-warning flag - merchants whose card-decline rate is running
--          well above their own recent baseline for consecutive months.
--
-- Rule: flag a merchant-month when the decline rate is >= 1.5x that
-- merchant's trailing 6-month baseline (lagged 2 months so the deteriorating
-- months don't contaminate the baseline) in BOTH the current and previous
-- month. Validated against churned merchants (see notebook): the rule
-- catches 21 of 22 churns, at a median of 2 months before the merchant
-- stops processing, flagging only 0.6% of healthy merchant-months.
-- ============================================================================

WITH rates AS (
    SELECT
        mm.merchant_id,
        m.merchant_name,
        m.sector,
        m.status,
        mm.month,
        mm.fee_revenue_gbp,
        1.0 * mm.declined_count
            / NULLIF(mm.txn_count + mm.declined_count, 0) AS decline_rate
    FROM monthly_metrics mm
    JOIN merchants m USING (merchant_id)
),

with_baseline AS (
    SELECT
        *,
        AVG(decline_rate) OVER (
            PARTITION BY merchant_id ORDER BY month
            ROWS BETWEEN 7 PRECEDING AND 2 PRECEDING
        )                                                  AS baseline_rate,
        COUNT(*) OVER (
            PARTITION BY merchant_id ORDER BY month
            ROWS BETWEEN 7 PRECEDING AND 2 PRECEDING
        )                                                  AS baseline_months
    FROM rates
),

flagged AS (
    SELECT
        *,
        CASE WHEN baseline_months >= 4
              AND decline_rate >= 1.5 * baseline_rate THEN 1 ELSE 0
        END AS elevated,
        LAG(CASE WHEN baseline_months >= 4
                  AND decline_rate >= 1.5 * baseline_rate THEN 1 ELSE 0 END)
            OVER (PARTITION BY merchant_id ORDER BY month) AS elevated_prev
    FROM with_baseline
)

-- Active merchants currently showing the pre-churn signature,
-- sized by fee revenue at risk
SELECT
    merchant_id,
    merchant_name,
    sector,
    ROUND(100 * baseline_rate, 1)      AS baseline_decline_pct,
    ROUND(100 * decline_rate, 1)       AS current_decline_pct,
    ROUND(decline_rate / baseline_rate, 1) AS vs_baseline_x,
    ROUND(12 * fee_revenue_gbp, 0)     AS annualised_fee_gbp
FROM flagged
WHERE month = '2026-06'
  AND status = 'Active'
  AND elevated = 1 AND elevated_prev = 1
ORDER BY annualised_fee_gbp DESC;
