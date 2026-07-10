-- ============================================================================
-- Project 01 - Supply Chain OTIF Analysis
-- File: 04_delivery_day_analysis.sql
-- Author: Blessed Tapiwa Dongo
-- Purpose: Late-delivery rate by scheduled delivery day of week.
--          Tests the hypothesis that the problem is partly OUR receiving
--          capacity, not just supplier performance.
-- ============================================================================

WITH po_flagged AS (
    SELECT
        STRFTIME(po.expected_delivery_date, '%A') AS scheduled_day,
        EXTRACT(ISODOW FROM po.expected_delivery_date) AS day_num,
        CASE WHEN po.actual_delivery_date > po.expected_delivery_date
             THEN 1 ELSE 0 END AS is_late
    FROM purchase_orders po
    WHERE po.status = 'Closed'
      AND po.order_date >= DATE '2025-07-01'
)

SELECT
    scheduled_day,
    COUNT(*)                                   AS deliveries,
    SUM(is_late)                               AS late_deliveries,
    ROUND(100.0 * SUM(is_late) / COUNT(*), 1)  AS late_pct
FROM po_flagged
GROUP BY scheduled_day, day_num
ORDER BY day_num;
