-- ============================================================================
-- Project 02 - Merchant Performance & Forecasting
-- File: 03_cohort_ramp.sql
-- Author: Blessed Tapiwa Dongo
-- Purpose: How quickly do new merchants ramp to steady-state volume?
--          Volume indexed to each merchant's own month-12+ average, by
--          months since onboarding. Informs revenue forecasts for newly
--          signed merchants.
-- ============================================================================

WITH monthly AS (
    SELECT
        mm.merchant_id,
        mm.txn_value_gbp,
        -- months since onboarding (both stored as 'YYYY-MM' strings)
        (CAST(SUBSTR(mm.month, 1, 4) AS INT) * 12 + CAST(SUBSTR(mm.month, 6, 2) AS INT))
        - (CAST(SUBSTR(m.onboarded_month, 1, 4) AS INT) * 12 + CAST(SUBSTR(m.onboarded_month, 6, 2) AS INT))
                                                   AS months_since_onboard
    FROM monthly_metrics mm
    JOIN merchants m USING (merchant_id)
    WHERE m.status = 'Active'
),

steady AS (  -- each merchant's own mature-volume benchmark
    SELECT merchant_id, AVG(txn_value_gbp) AS steady_value
    FROM monthly
    WHERE months_since_onboard >= 12
    GROUP BY merchant_id
    HAVING COUNT(*) >= 3
)

SELECT
    mo.months_since_onboard,
    COUNT(*)                                            AS observations,
    ROUND(100.0 * AVG(mo.txn_value_gbp / st.steady_value), 0) AS volume_index_pct
FROM monthly mo
JOIN steady st USING (merchant_id)
WHERE mo.months_since_onboard BETWEEN 0 AND 12
GROUP BY mo.months_since_onboard
ORDER BY mo.months_since_onboard;
