-- ============================================================================
-- Project 01 - Supply Chain OTIF Analysis
-- File: 02_monthly_otif_trend.sql
-- Author: Blessed Tapiwa Dongo
-- Purpose: Monthly OTIF trend across the full 24-month window, overall and
--          split for Meridian Fresh Produce vs everyone else - the query
--          that first isolated the Jan 2026 step-change.
-- ============================================================================

WITH po_flagged AS (
    SELECT
        DATE_TRUNC('month', po.order_date) AS order_month,
        s.supplier_name,
        CASE
            WHEN po.actual_delivery_date <= po.expected_delivery_date
             AND po.received_qty >= po.expected_qty
            THEN 1 ELSE 0
        END AS is_otif
    FROM purchase_orders po
    JOIN suppliers s ON s.supplier_id = po.supplier_id
    WHERE po.status = 'Closed'
)

SELECT
    order_month,
    COUNT(*)                                  AS po_count,
    ROUND(100.0 * SUM(is_otif) / COUNT(*), 1) AS otif_pct_all,
    ROUND(100.0 * SUM(CASE WHEN supplier_name = 'Meridian Fresh Produce'
                           THEN is_otif END)
                / NULLIF(COUNT(CASE WHEN supplier_name = 'Meridian Fresh Produce'
                                    THEN 1 END), 0), 1) AS otif_pct_meridian,
    ROUND(100.0 * SUM(CASE WHEN supplier_name <> 'Meridian Fresh Produce'
                           THEN is_otif END)
                / NULLIF(COUNT(CASE WHEN supplier_name <> 'Meridian Fresh Produce'
                                    THEN 1 END), 0), 1) AS otif_pct_rest
FROM po_flagged
GROUP BY order_month
ORDER BY order_month;
