-- ============================================================================
-- Project 03 - Warehouse KPI Dashboard
-- File: 02_accuracy_by_shift_and_tenure.sql
-- Author: Blessed Tapiwa Dongo
-- Purpose: Where do mispicks actually come from? Splits pick accuracy by
--          shift and by operative tenure, because "improve accuracy" is
--          not a plan and "retrain the night shift's new starters" is.
--
-- Mispicks are expressed per 1,000 lines - the unit warehouse supervisors
-- actually use, and comparable across operatives of different output.
-- ============================================================================

WITH sessions AS (
    SELECT
        ps.session_date,
        ps.operative_id,
        o.operative_name,
        o.shift,
        ps.zone,
        ps.lines_picked,
        ps.hours_worked,
        ps.mispicks,
        DATE_DIFF('day', o.hire_date, ps.session_date) AS tenure_days
    FROM pick_sessions ps
    JOIN operatives o USING (operative_id)
),

tenure_banded AS (
    SELECT
        *,
        CASE
            WHEN tenure_days <  30 THEN '1. Under 30 days'
            WHEN tenure_days <  90 THEN '2. 30-90 days'
            WHEN tenure_days < 365 THEN '3. 3-12 months'
            ELSE                        '4. Over 12 months'
        END AS tenure_band
    FROM sessions
)

-- 1. Shift x tenure: the interaction is the story
SELECT
    shift,
    tenure_band,
    COUNT(DISTINCT operative_id)                                  AS operatives,
    SUM(lines_picked)                                             AS lines_picked,
    ROUND(1000.0 * SUM(mispicks) / SUM(lines_picked), 2)          AS mispicks_per_1000,
    ROUND(SUM(lines_picked) / SUM(hours_worked), 1)               AS lines_per_hour
FROM tenure_banded
GROUP BY shift, tenure_band
ORDER BY shift, tenure_band;

-- 2. Individual operatives worth a conversation this week:
--    high error rate on meaningful volume, last 30 days
WITH tenure_banded AS (
    SELECT
        ps.session_date,
        ps.operative_id,
        o.operative_name,
        o.shift,
        ps.lines_picked,
        ps.hours_worked,
        ps.mispicks,
        DATE_DIFF('day', o.hire_date, ps.session_date) AS tenure_days
    FROM pick_sessions ps
    JOIN operatives o USING (operative_id)
)
SELECT
    operative_name,
    shift,
    MIN(tenure_days)                                              AS tenure_days,
    SUM(lines_picked)                                             AS lines_30d,
    SUM(mispicks)                                                 AS mispicks_30d,
    ROUND(1000.0 * SUM(mispicks) / SUM(lines_picked), 2)          AS mispicks_per_1000,
    ROUND(SUM(lines_picked) / SUM(hours_worked), 1)               AS lines_per_hour
FROM tenure_banded
WHERE session_date >= DATE '2026-06-01'
GROUP BY operative_id, operative_name, shift
HAVING SUM(lines_picked) >= 2000
ORDER BY mispicks_per_1000 DESC
LIMIT 10;
