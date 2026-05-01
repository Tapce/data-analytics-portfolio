# KPI Definitions — Operational & Supply Chain

A reference doc I keep updated. Half the value in any analysis is locking down definitions before you start querying — without that, "OTIF was 87%" means different things to different people.

## OTIF — On Time In Full

**Definition:** A purchase order is OTIF if **both** the actual delivery date is on or before the expected delivery date **and** the received quantity meets or exceeds the expected quantity.

**Edge cases to decide explicitly with stakeholders:**
- Partial deliveries — does receipt of 95% count as "in full"? (Usually no, but some businesses use a tolerance.)
- Early delivery — does arriving 5 days early count as "on time"? (Usually yes for inbound; sometimes no for finished-goods outbound.)
- Cancellations and amendments — do amended POs reset the clock?

## Stock Accuracy

**Definition:** Percentage of SKU-locations where the system quantity matches the physically counted quantity within an agreed tolerance.

**Common variants:**
- Strict: zero variance allowed.
- Tolerant: variance of ±1 unit or ±X% accepted.
- Value-weighted: variance weighted by SKU value.

## Pick Accuracy

**Definition:** Percentage of order lines picked correctly (right SKU, right quantity) with no downstream amendment.

## Order Fulfilment Rate

**Definition:** Percentage of customer orders fully shipped within the committed lead time.

---


