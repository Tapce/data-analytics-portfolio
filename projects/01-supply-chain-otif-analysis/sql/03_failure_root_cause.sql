-- ============================================================================
-- Project 01 - Supply Chain OTIF Analysis
-- File: 03_failure_root_cause.sql
-- Author: Blessed Tapiwa Dongo
-- Purpose: Segment OTIF failures by failure mode and supplier category.
--          "We're missing OTIF" is not actionable; "produce suppliers
--          short-ship and Friday deliveries run late" is.
-- ============================================================================

WITH po_flagged AS (
    SELECT
        s.category,
        CASE
            WHEN po.actual_delivery_date > po.expected_delivery_date
             AND po.received_qty < po.expected_qty THEN 'Late & short'
            WHEN po.actual_delivery_date > po.expected_delivery_date THEN 'Late'
            WHEN po.received_qty < po.expected_qty THEN 'Short'
            ELSE 'On time & in full'
        END AS failure_reason
    FROM purchase_orders po
    JOIN suppliers s ON s.supplier_id = po.supplier_id
    WHERE po.status = 'Closed'
      AND po.order_date >= DATE '2025-07-01'
)

-- Failure mode mix by category (row % within category)
SELECT
    category,
    COUNT(*) AS po_count,
    ROUND(100.0 * SUM(CASE WHEN failure_reason = 'On time & in full'
                           THEN 1 ELSE 0 END) / COUNT(*), 1) AS otif_pct,
    ROUND(100.0 * SUM(CASE WHEN failure_reason IN ('Late', 'Late & short')
                           THEN 1 ELSE 0 END) / COUNT(*), 1) AS late_pct,
    ROUND(100.0 * SUM(CASE WHEN failure_reason IN ('Short', 'Late & short')
                           THEN 1 ELSE 0 END) / COUNT(*), 1) AS short_pct
FROM po_flagged
GROUP BY category
ORDER BY otif_pct ASC;
