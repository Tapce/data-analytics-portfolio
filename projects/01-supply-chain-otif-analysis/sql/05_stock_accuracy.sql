-- ============================================================================
-- Project 01 - Supply Chain OTIF Analysis
-- File: 05_stock_accuracy.sql
-- Author: Blessed Tapiwa Dongo
-- Purpose: Cycle-count stock accuracy by warehouse zone and SKU velocity.
--          Accuracy = counts where counted qty exactly matches system qty.
--
-- Schema:
--   cycle_counts(sku_id, zone, velocity_class, count_date,
--                system_qty, counted_qty)
-- ============================================================================

-- 1. Accuracy by zone
SELECT
    zone,
    COUNT(*)                                              AS counts,
    SUM(CASE WHEN counted_qty = system_qty THEN 1 ELSE 0 END) AS accurate,
    ROUND(100.0 * SUM(CASE WHEN counted_qty = system_qty THEN 1 ELSE 0 END)
                / COUNT(*), 1)                            AS accuracy_pct,
    ROUND(AVG(CASE WHEN counted_qty <> system_qty
                   THEN ABS(counted_qty - system_qty) END), 1) AS avg_abs_variance
FROM cycle_counts
GROUP BY zone
ORDER BY accuracy_pct ASC;

-- 2. Accuracy by velocity class (A = fastest movers)
SELECT
    velocity_class,
    COUNT(*)                                              AS counts,
    ROUND(100.0 * SUM(CASE WHEN counted_qty = system_qty THEN 1 ELSE 0 END)
                / COUNT(*), 1)                            AS accuracy_pct
FROM cycle_counts
GROUP BY velocity_class
ORDER BY velocity_class;

-- 3. Zone C, A-class SKUs: the intersection that drives the miss
SELECT
    zone,
    velocity_class,
    COUNT(*)                                              AS counts,
    ROUND(100.0 * SUM(CASE WHEN counted_qty = system_qty THEN 1 ELSE 0 END)
                / COUNT(*), 1)                            AS accuracy_pct
FROM cycle_counts
GROUP BY zone, velocity_class
HAVING COUNT(*) >= 30
ORDER BY accuracy_pct ASC
LIMIT 5;
