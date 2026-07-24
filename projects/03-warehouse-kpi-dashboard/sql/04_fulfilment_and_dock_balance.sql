-- ============================================================================
-- Project 03 - Warehouse KPI Dashboard
-- File: 04_fulfilment_and_dock_balance.sql
-- Author: Blessed Tapiwa Dongo
-- Purpose: Order fulfilment by weekday, and the inbound/outbound balance
--          that explains it. A fulfilment dip is rarely about picking -
--          it's usually about what else the same people were doing.
-- ============================================================================

-- 1. Fulfilment by weekday, split into its two failure modes
WITH flagged AS (
    SELECT
        STRFTIME(order_date, '%A')                       AS weekday,
        EXTRACT(ISODOW FROM order_date)                  AS day_num,
        CASE WHEN actual_dispatch_date <= promised_dispatch_date
              AND lines_shipped >= lines_ordered
             THEN 1 ELSE 0 END                           AS is_otif,
        CASE WHEN actual_dispatch_date > promised_dispatch_date
             THEN 1 ELSE 0 END                           AS is_late,
        CASE WHEN lines_shipped < lines_ordered
             THEN 1 ELSE 0 END                           AS is_short
    FROM orders
)
SELECT
    weekday,
    COUNT(*)                                             AS orders,
    ROUND(100.0 * SUM(is_otif)  / COUNT(*), 1)           AS fulfilment_pct,
    ROUND(100.0 * SUM(is_late)  / COUNT(*), 1)           AS late_pct,
    ROUND(100.0 * SUM(is_short) / COUNT(*), 1)           AS short_pct
FROM flagged
GROUP BY weekday, day_num
ORDER BY day_num;

-- 2. Dock balance by weekday: is goods-in competing with dispatch
--    for the same hours and the same people?
SELECT
    STRFTIME(throughput_date, '%A')                      AS weekday,
    ROUND(AVG(inbound_units))                            AS avg_inbound_units,
    ROUND(AVG(outbound_units))                           AS avg_outbound_units,
    ROUND(AVG(inbound_units) / AVG(outbound_units), 2)   AS inbound_to_outbound_ratio,
    ROUND(AVG(goods_in_hours), 1)                        AS avg_goods_in_hours
FROM throughput
GROUP BY weekday, EXTRACT(ISODOW FROM throughput_date)
ORDER BY EXTRACT(ISODOW FROM throughput_date);
