-- ============================================================================
-- Project 03 - Warehouse KPI Dashboard
-- File: 01_daily_kpi_summary.sql
-- Author: Blessed Tapiwa Dongo
-- Purpose: The dashboard's top strip - one row per day with every headline
--          KPI, plus a 7-day rolling view so a supervisor sees trend, not
--          just yesterday's noise.
--
-- Schema (see data/sample/):
--   operatives(operative_id, operative_name, shift, hire_date)
--   pick_sessions(session_date, operative_id, zone, hours_worked,
--                 lines_picked, units_picked, mispicks)
--   orders(order_id, order_date, promised_dispatch_date,
--          actual_dispatch_date, lines_ordered, lines_shipped)
--   throughput(throughput_date, inbound_units, outbound_units, goods_in_hours)
-- ============================================================================

WITH picking AS (
    SELECT
        session_date                            AS kpi_date,
        SUM(lines_picked)                       AS lines_picked,
        SUM(units_picked)                       AS units_picked,
        SUM(hours_worked)                       AS hours_worked,
        SUM(mispicks)                           AS mispicks
    FROM pick_sessions
    GROUP BY session_date
),

fulfilment AS (
    SELECT
        order_date                              AS kpi_date,
        COUNT(*)                                AS orders,
        SUM(CASE WHEN actual_dispatch_date <= promised_dispatch_date
                  AND lines_shipped >= lines_ordered
                 THEN 1 ELSE 0 END)             AS otif_orders
    FROM orders
    GROUP BY order_date
),

daily AS (
    SELECT
        p.kpi_date,
        p.lines_picked,
        p.units_picked,
        ROUND(p.lines_picked / NULLIF(p.hours_worked, 0), 1)          AS lines_per_hour,
        ROUND(p.units_picked / NULLIF(p.hours_worked, 0), 1)          AS units_per_hour,
        ROUND(100.0 * (1 - p.mispicks / NULLIF(p.lines_picked, 0)), 2) AS pick_accuracy_pct,
        ROUND(1000.0 * p.mispicks / NULLIF(p.lines_picked, 0), 2)     AS mispicks_per_1000,
        ROUND(100.0 * f.otif_orders / NULLIF(f.orders, 0), 1)         AS fulfilment_pct,
        t.inbound_units,
        t.outbound_units
    FROM picking p
    JOIN fulfilment f USING (kpi_date)
    JOIN throughput t ON t.throughput_date = p.kpi_date
)

SELECT
    kpi_date,
    STRFTIME(kpi_date, '%a')                                          AS day,
    lines_picked,
    lines_per_hour,
    pick_accuracy_pct,
    fulfilment_pct,
    inbound_units,
    outbound_units,
    -- 7-day rolling, so a single bad day doesn't trigger a witch-hunt
    ROUND(AVG(pick_accuracy_pct) OVER (ORDER BY kpi_date
          ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2)               AS accuracy_7d,
    ROUND(AVG(fulfilment_pct) OVER (ORDER BY kpi_date
          ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1)               AS fulfilment_7d,
    ROUND(AVG(lines_per_hour) OVER (ORDER BY kpi_date
          ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1)               AS lines_per_hour_7d
FROM daily
ORDER BY kpi_date DESC
LIMIT 14;
