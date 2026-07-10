-- ============================================================================
-- Project 01 - Supply Chain OTIF Analysis
-- File: 01_otif_by_supplier.sql
-- Author: Blessed Tapiwa Dongo
-- Purpose: Calculate on-time-in-full (OTIF) performance per supplier
--          and rank suppliers by recovery opportunity.
--
-- Schema (see data/sample/):
--   purchase_orders(po_id, supplier_id, order_date, expected_delivery_date,
--                   actual_delivery_date, expected_qty, received_qty, status)
--   suppliers(supplier_id, supplier_name, supplier_tier, category, country)
--
-- Window: final 12 months of the dataset (Jul 2025 - Jun 2026), anchored
-- explicitly so results are reproducible. In production this would be
-- CURRENT_DATE - INTERVAL '12 months'.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. OTIF flag per purchase order
-- ----------------------------------------------------------------------------
WITH po_flagged AS (
    SELECT
        po.po_id,
        po.supplier_id,
        s.supplier_name,
        s.supplier_tier,
        s.category,
        po.order_date,
        po.expected_delivery_date,
        po.actual_delivery_date,
        po.expected_qty,
        po.received_qty,
        CASE
            WHEN po.actual_delivery_date <= po.expected_delivery_date
             AND po.received_qty >= po.expected_qty
            THEN 1 ELSE 0
        END AS is_otif,
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
),

-- ----------------------------------------------------------------------------
-- 2. Aggregate OTIF performance per supplier
-- ----------------------------------------------------------------------------
supplier_summary AS (
    SELECT
        supplier_id,
        supplier_name,
        supplier_tier,
        category,
        COUNT(*)                                         AS po_count,
        SUM(is_otif)                                     AS otif_count,
        ROUND(100.0 * SUM(is_otif) / COUNT(*), 1)        AS otif_pct,
        SUM(CASE WHEN failure_reason IN ('Late', 'Late & short')
                 THEN 1 ELSE 0 END)                      AS late_count,
        SUM(CASE WHEN failure_reason IN ('Short', 'Late & short')
                 THEN 1 ELSE 0 END)                      AS short_count
    FROM po_flagged
    GROUP BY supplier_id, supplier_name, supplier_tier, category
)

-- ----------------------------------------------------------------------------
-- 3. Rank suppliers by recovery opportunity
--    (high PO volume + low OTIF % = biggest win)
-- ----------------------------------------------------------------------------
SELECT
    supplier_name,
    supplier_tier,
    category,
    po_count,
    otif_pct,
    late_count,
    short_count,
    (po_count - otif_count) AS failed_pos,
    RANK() OVER (ORDER BY (po_count - otif_count) DESC) AS recovery_rank
FROM supplier_summary
WHERE po_count >= 12  -- at least ~1 PO/month; ranking noise below that
ORDER BY recovery_rank
LIMIT 15;
