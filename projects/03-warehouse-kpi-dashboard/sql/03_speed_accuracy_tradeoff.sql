-- ============================================================================
-- Project 03 - Warehouse KPI Dashboard
-- File: 03_speed_accuracy_tradeoff.sql
-- Author: Blessed Tapiwa Dongo
-- Purpose: Settle the argument every warehouse has - does pushing the pick
--          rate cost accuracy, and if so, from what point?
--
-- Method: compare each session's pick rate to that OPERATIVE'S OWN median
--          rate, so we measure "pushed harder than normal" rather than
--          "naturally quick". Fast pickers are not the problem; pushed
--          pickers are.
-- ============================================================================

WITH rated AS (
    SELECT
        operative_id,
        session_date,
        lines_picked,
        mispicks,
        lines_picked / NULLIF(hours_worked, 0) AS lines_per_hour
    FROM pick_sessions
    WHERE hours_worked >= 2          -- ignore part-days, the rate is unstable
),

with_norm AS (
    SELECT
        *,
        MEDIAN(lines_per_hour) OVER (PARTITION BY operative_id) AS own_median_rate
    FROM rated
),

banded AS (
    SELECT
        *,
        lines_per_hour / NULLIF(own_median_rate, 0) AS push_ratio,
        CASE
            WHEN lines_per_hour / own_median_rate < 0.90 THEN '1. Under 90% of own norm'
            WHEN lines_per_hour / own_median_rate < 1.00 THEN '2. 90-100%'
            WHEN lines_per_hour / own_median_rate < 1.10 THEN '3. 100-110%'
            WHEN lines_per_hour / own_median_rate < 1.20 THEN '4. 110-120%'
            ELSE                                              '5. Over 120%'
        END AS push_band
    FROM with_norm
)

SELECT
    push_band,
    COUNT(*)                                              AS sessions,
    SUM(lines_picked)                                     AS lines_picked,
    ROUND(1000.0 * SUM(mispicks) / SUM(lines_picked), 2)  AS mispicks_per_1000
FROM banded
GROUP BY push_band
ORDER BY push_band;
