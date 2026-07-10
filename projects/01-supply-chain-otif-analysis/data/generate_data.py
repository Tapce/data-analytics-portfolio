"""
Project 01 — Supply Chain OTIF & Stock Accuracy Analysis
Simulated dataset generator.

Generates a realistic, fully synthetic dataset modelled on a UK food & drink
distribution operation: suppliers, purchase orders (24 months) and warehouse
cycle counts (12 months). Patterns in the data (supplier degradation,
category-specific short-shipping, receiving-day effects, zone-level stock
variance) are seeded deliberately so the analysis has genuine root causes
to uncover — the same shapes I saw repeatedly in live operations, with all
names, volumes and dates invented.

No real company data is used anywhere in this project.

Usage:
    python generate_data.py     # writes CSVs to ./sample/

Reproducible: fixed RNG seed (42).
"""

from __future__ import annotations

import os
from datetime import date, timedelta

import numpy as np
import pandas as pd

RNG = np.random.default_rng(42)

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sample")

PERIOD_START = date(2024, 7, 1)
PERIOD_END = date(2026, 6, 30)

CATEGORIES = ["Produce", "Chilled", "Ambient", "Frozen", "Packaging"]

# Typical quoted lead time (days) by category
LEAD_TIME = {"Produce": 3, "Chilled": 4, "Ambient": 8, "Frozen": 7, "Packaging": 12}

SUPPLIER_NAMES = [
    # Tier 1 — strategic, high volume (8)
    ("Meridian Fresh Produce", 1, "Produce"),
    ("Albion Chilled Logistics", 1, "Chilled"),
    ("Harrogate Fine Foods", 1, "Ambient"),
    ("Polar Crest Frozen", 1, "Frozen"),
    ("Wexford Dairy Partners", 1, "Chilled"),
    ("Stonebridge Provisions", 1, "Ambient"),
    ("Caldera Packaging Group", 1, "Packaging"),
    ("Northgate Produce Co", 1, "Produce"),
    # Tier 2 — regular (15)
    ("Bramley & Finch", 2, "Ambient"),
    ("Tidewater Seafoods", 2, "Chilled"),
    ("Ashcombe Orchards", 2, "Produce"),
    ("Redmoor Bakery Supplies", 2, "Ambient"),
    ("Glacier Point Foods", 2, "Frozen"),
    ("Silverbeck Beverages", 2, "Ambient"),
    ("Foxglove Farm Foods", 2, "Produce"),
    ("Kestrel Cold Chain", 2, "Frozen"),
    ("Marlowe Ingredients", 2, "Ambient"),
    ("Dunmore Creamery", 2, "Chilled"),
    ("Hartfield Pack Solutions", 2, "Packaging"),
    ("Ombersley Growers", 2, "Produce"),
    ("Larkspur Foods", 2, "Ambient"),
    ("Cromwell Frozen Goods", 2, "Frozen"),
    ("Bellweather Dairy", 2, "Chilled"),
    # Tier 3 — tail / spot suppliers (17)
    ("Tarn Valley Produce", 3, "Produce"),
    ("Elmsworth Trading", 3, "Ambient"),
    ("Quayside Fish Merchants", 3, "Chilled"),
    ("Birchall & Sons", 3, "Ambient"),
    ("Mosswood Farm", 3, "Produce"),
    ("Arden Vale Foods", 3, "Ambient"),
    ("Setter Ridge Frozen", 3, "Frozen"),
    ("Copperfield Supplies", 3, "Packaging"),
    ("Nettlebed Growers", 3, "Produce"),
    ("Wharfedale Provisions", 3, "Ambient"),
    ("Saltmarsh Foods", 3, "Chilled"),
    ("Ivybridge Trading Co", 3, "Ambient"),
    ("Penrose Orchard Direct", 3, "Produce"),
    ("Gullwing Seafood", 3, "Chilled"),
    ("Thornbury Pack & Print", 3, "Packaging"),
    ("Eastholme Farm Foods", 3, "Produce"),
    ("Ravenscar Frozen Foods", 3, "Frozen"),
]

# POs per month by tier (approximate Poisson means)
PO_RATE = {1: 11.0, 2: 4.5, 3: 1.4}

# Baseline failure probabilities by tier
BASE_LATE = {1: 0.045, 2: 0.085, 3: 0.14}
BASE_SHORT = {1: 0.03, 2: 0.06, 3: 0.10}

# Seeded patterns ------------------------------------------------------------
# 1. Meridian Fresh Produce degrades sharply from Jan 2026 (depot relocation).
MERIDIAN_DEGRADE_FROM = date(2026, 1, 1)
MERIDIAN_LATE_AFTER = 0.30
MERIDIAN_SHORT_AFTER = 0.09

# 2. Produce category short-ships more (field availability / grading).
PRODUCE_SHORT_UPLIFT = 0.05

# 3. Chronic short-shippers in the tier-3 produce tail.
CHRONIC_SHORT = {"Tarn Valley Produce": 0.24, "Nettlebed Growers": 0.20}

# 4. Friday deliveries are ~2.3x more likely to be late (receiving capacity).
FRIDAY_LATE_MULT = 2.3


def month_range(start: date, end: date):
    d = date(start.year, start.month, 1)
    while d <= end:
        yield d
        d = date(d.year + (d.month == 12), d.month % 12 + 1, 1)


def build_suppliers() -> pd.DataFrame:
    rows = []
    for i, (name, tier, category) in enumerate(SUPPLIER_NAMES, start=1):
        rows.append(
            {
                "supplier_id": f"SUP-{i:03d}",
                "supplier_name": name,
                "supplier_tier": tier,
                "category": category,
                "country": "United Kingdom" if RNG.random() < 0.8 else RNG.choice(
                    ["Netherlands", "Ireland", "Spain", "France"]
                ),
            }
        )
    return pd.DataFrame(rows)


def build_purchase_orders(suppliers: pd.DataFrame) -> pd.DataFrame:
    rows = []
    po_seq = 1
    for sup in suppliers.itertuples(index=False):
        rate = PO_RATE[sup.supplier_tier]
        # Meridian is the biggest single supplier by volume
        if sup.supplier_name == "Meridian Fresh Produce":
            rate = 16.0
        for month_start in month_range(PERIOD_START, PERIOD_END):
            n_pos = RNG.poisson(rate)
            days_in_month = (
                date(
                    month_start.year + (month_start.month == 12),
                    month_start.month % 12 + 1,
                    1,
                )
                - month_start
            ).days
            for _ in range(n_pos):
                order_date = month_start + timedelta(
                    days=int(RNG.integers(0, days_in_month))
                )
                lead = LEAD_TIME[sup.category] + int(RNG.integers(-1, 3))
                lead = max(2, lead)
                expected_delivery = order_date + timedelta(days=lead)

                # --- late? ---
                p_late = BASE_LATE[sup.supplier_tier]
                if (
                    sup.supplier_name == "Meridian Fresh Produce"
                    and order_date >= MERIDIAN_DEGRADE_FROM
                ):
                    p_late = MERIDIAN_LATE_AFTER
                if expected_delivery.weekday() == 4:  # Friday
                    p_late = min(0.95, p_late * FRIDAY_LATE_MULT)

                is_late = RNG.random() < p_late
                if is_late:
                    # most lates are 1-2 days; a long tail up to a week
                    days_late = int(np.clip(RNG.gamma(1.6, 1.3), 1, 7))
                    actual_delivery = expected_delivery + timedelta(days=days_late)
                else:
                    # occasionally early
                    actual_delivery = expected_delivery - timedelta(
                        days=int(RNG.random() < 0.12)
                    )

                # --- short? ---
                p_short = BASE_SHORT[sup.supplier_tier]
                if sup.category == "Produce":
                    p_short += PRODUCE_SHORT_UPLIFT
                p_short = CHRONIC_SHORT.get(sup.supplier_name, p_short)
                if (
                    sup.supplier_name == "Meridian Fresh Produce"
                    and order_date >= MERIDIAN_DEGRADE_FROM
                ):
                    p_short = MERIDIAN_SHORT_AFTER

                expected_qty = int(np.clip(RNG.lognormal(5.6, 0.7), 40, 4000))
                if RNG.random() < p_short:
                    fill = RNG.uniform(0.70, 0.97)
                    received_qty = int(expected_qty * fill)
                else:
                    received_qty = expected_qty

                rows.append(
                    {
                        "po_id": f"PO-{po_seq:06d}",
                        "supplier_id": sup.supplier_id,
                        "order_date": order_date,
                        "expected_delivery_date": expected_delivery,
                        "actual_delivery_date": actual_delivery,
                        "expected_qty": expected_qty,
                        "received_qty": received_qty,
                        "status": "Closed",
                    }
                )
                po_seq += 1
    df = pd.DataFrame(rows).sort_values("order_date").reset_index(drop=True)
    return df


def build_cycle_counts() -> pd.DataFrame:
    """Monthly cycle counts, final 12 months. Zone C (high-velocity pick face)
    carries most of the variance; A-class SKUs are counted-wrong more often."""
    zones = ["A", "B", "C", "D", "E"]
    n_skus = 250
    skus = pd.DataFrame(
        {
            "sku_id": [f"SKU-{i:04d}" for i in range(1, n_skus + 1)],
            "zone": RNG.choice(zones, n_skus, p=[0.22, 0.22, 0.26, 0.18, 0.12]),
            "velocity_class": RNG.choice(["A", "B", "C"], n_skus, p=[0.2, 0.35, 0.45]),
        }
    )

    rows = []
    for month_start in month_range(date(2025, 7, 1), PERIOD_END):
        for sku in skus.itertuples(index=False):
            count_date = month_start + timedelta(days=int(RNG.integers(0, 28)))
            system_qty = int(np.clip(RNG.lognormal(4.4, 0.9), 5, 2500))

            p_err = 0.020
            if sku.zone == "C":
                p_err = 0.085
            if sku.velocity_class == "A":
                p_err *= 1.8

            if RNG.random() < p_err:
                # variance of 1-12% of system qty, either direction
                magnitude = max(1, int(system_qty * RNG.uniform(0.01, 0.12)))
                counted_qty = system_qty + int(RNG.choice([-1, 1])) * magnitude
            else:
                counted_qty = system_qty

            rows.append(
                {
                    "sku_id": sku.sku_id,
                    "zone": sku.zone,
                    "velocity_class": sku.velocity_class,
                    "count_date": count_date,
                    "system_qty": system_qty,
                    "counted_qty": counted_qty,
                }
            )
    return pd.DataFrame(rows).sort_values(["count_date", "sku_id"]).reset_index(drop=True)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    suppliers = build_suppliers()
    pos = build_purchase_orders(suppliers)
    counts = build_cycle_counts()

    suppliers.to_csv(os.path.join(OUT_DIR, "suppliers.csv"), index=False)
    pos.to_csv(os.path.join(OUT_DIR, "purchase_orders.csv"), index=False)
    counts.to_csv(os.path.join(OUT_DIR, "cycle_counts.csv"), index=False)

    print(f"suppliers        : {len(suppliers):>6,} rows")
    print(f"purchase_orders  : {len(pos):>6,} rows")
    print(f"cycle_counts     : {len(counts):>6,} rows")
    print(f"written to {OUT_DIR}")


if __name__ == "__main__":
    main()
