"""
Project 02 — Merchant Performance & Forecasting
Simulated dataset generator.

Generates a fully synthetic merchant-acquiring portfolio: ~185 merchants and
30 months of monthly processing metrics (Jan 2024 – Jun 2026). Patterns are
seeded deliberately so the analysis has real structure to find:

  * merchants that churn show a rising decline-rate signature in their final
    months (the early-warning problem),
  * new merchants ramp to steady-state volume over ~5-6 months,
  * sector-specific seasonality (retail/online Q4 peak, travel summer peak),
  * revenue concentrated in a small top tier of merchants.

These are the shapes I worked with in live merchant analytics; every name,
volume and date here is invented. No real company data is used.

Usage:
    python generate_data.py     # writes CSVs to ./sample/

Reproducible: fixed RNG seed (7).
"""

from __future__ import annotations

import os
from datetime import date

import numpy as np
import pandas as pd

RNG = np.random.default_rng(7)

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sample")

MONTHS = pd.period_range("2024-01", "2026-06", freq="M")

SECTORS = ["Retail", "Hospitality", "Online", "Services", "Travel"]
SECTOR_P = [0.30, 0.22, 0.20, 0.18, 0.10]

# Average transaction value (GBP) and baseline decline rate by sector
ATV = {"Retail": 28, "Hospitality": 19, "Online": 42, "Services": 85, "Travel": 240}
BASE_DECLINE = {"Retail": 0.025, "Hospitality": 0.022, "Online": 0.045,
                "Services": 0.020, "Travel": 0.035}
# Fee yield (blended % of processed value) by sector
FEE_YIELD = {"Retail": 0.014, "Hospitality": 0.016, "Online": 0.019,
             "Services": 0.012, "Travel": 0.011}

# Seasonality factor by sector and calendar month (1-12)
def seasonal_factor(sector: str, month: int) -> float:
    if sector in ("Retail", "Online"):
        return {11: 1.25, 12: 1.45, 1: 0.85}.get(month, 1.0)
    if sector == "Travel":
        return {6: 1.30, 7: 1.45, 8: 1.35, 1: 0.70, 2: 0.75}.get(month, 1.0)
    if sector == "Hospitality":
        return {12: 1.35, 7: 1.15, 8: 1.10, 1: 0.80}.get(month, 1.0)
    return 1.0  # Services

# Pre-churn signature applied to a merchant's final five active months
CHURN_DECLINE_MULT = [1.25, 1.7, 2.1, 2.6, 3.2]
CHURN_VOLUME_MULT = [0.97, 0.90, 0.80, 0.65, 0.50]

NAME_A = ["Bluewater", "Kingfisher", "Harborne", "Westcliff", "Oakhurst", "Fenwick",
          "Marlin", "Redgrave", "Silverton", "Ashdown", "Clearbrook", "Longacre",
          "Stanmore", "Brightwell", "Cedarfield", "Norbury", "Falconer", "Greystone",
          "Hollybank", "Ravensworth", "Millbrook", "Eastgate", "Thistledown", "Wychwood"]
NAME_B = {"Retail": ["Trading", "Retail", "Stores", "Supplies", "Home & Garden", "Outfitters"],
          "Hospitality": ["Kitchen", "Bistro", "Inns", "Coffee Co", "Taproom", "Eatery"],
          "Online": ["Direct", "Digital", "Online", "Commerce", "Marketplace", "Goods"],
          "Services": ["Consulting", "Clinics", "Motors", "Lettings", "Studios", "Training"],
          "Travel": ["Travel", "Tours", "Holidays", "Charters", "Escapes", "Journeys"]}


def build_merchants(n: int = 185) -> pd.DataFrame:
    rows = []
    used = set()
    for i in range(1, n + 1):
        sector = RNG.choice(SECTORS, p=SECTOR_P)
        while True:
            name = f"{RNG.choice(NAME_A)} {RNG.choice(NAME_B[sector])}"
            if name not in used:
                used.add(name)
                break
        # ~1/3 of the book predates the window; the rest onboard through it
        if RNG.random() < 0.35:
            onboarded = pd.Period("2023-12", freq="M") - int(RNG.integers(0, 36))
        else:
            onboarded = MONTHS[int(RNG.integers(0, len(MONTHS) - 1))]
        # steady-state monthly processed value, lognormal (median ~£45k)
        steady_value = float(np.clip(RNG.lognormal(10.7, 0.9), 4_000, 1_200_000))
        rows.append({"merchant_id": f"M-{i:04d}", "merchant_name": name,
                     "sector": sector, "onboarded_month": onboarded,
                     "steady_value": steady_value})
    df = pd.DataFrame(rows)

    # churners: active for >= 8 months, churn inside the window (not the first year)
    eligible = df[df.onboarded_month < pd.Period("2025-03", freq="M")].index
    churn_idx = RNG.choice(eligible, size=22, replace=False)
    df["churn_month"] = pd.Series(pd.NA, index=df.index, dtype="object")
    churn_candidates = pd.period_range("2025-01", "2026-05", freq="M")
    for idx in churn_idx:
        earliest = max(df.loc[idx, "onboarded_month"] + 8, churn_candidates[0])
        options = [m for m in churn_candidates if m >= earliest]
        df.loc[idx, "churn_month"] = RNG.choice(options)

    # at-risk merchants: active, but the first steps of the signature are
    # already visible at the end of the window
    active = df[df.churn_month.isna() & (df.onboarded_month < pd.Period("2025-09", freq="M"))].index
    df["at_risk"] = False
    df.loc[RNG.choice(active, size=7, replace=False), "at_risk"] = True
    return df


def build_monthly(merchants: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for m in merchants.itertuples(index=False):
        churn = m.churn_month if not pd.isna(m.churn_month) else None
        for per in MONTHS:
            if per < m.onboarded_month:
                continue
            if churn is not None and per > churn:
                continue

            months_live = (per - m.onboarded_month).n
            ramp = min(1.0, 0.25 + 0.15 * months_live)
            growth = 1.008 ** (per - MONTHS[0]).n  # gentle underlying growth
            noise = RNG.normal(1.0, 0.06)
            value = m.steady_value * ramp * growth * seasonal_factor(m.sector, per.month) * noise

            decline = BASE_DECLINE[m.sector] * RNG.normal(1.0, 0.12)

            if churn is not None:
                step = (per - churn).n + 4  # 0..4 over the final five months
                if 0 <= step <= 4:
                    decline *= CHURN_DECLINE_MULT[step]
                    value *= CHURN_VOLUME_MULT[step]
            if getattr(m, "at_risk", False):
                step = (per - MONTHS[-1]).n + 2  # final three months: first steps
                if 0 <= step <= 2:
                    decline *= CHURN_DECLINE_MULT[step]
                    value *= CHURN_VOLUME_MULT[step]

            atv = ATV[m.sector] * RNG.normal(1.0, 0.05)
            txn_count = max(10, int(value / atv))
            declined = RNG.binomial(txn_count, min(decline, 0.6))
            yield_ = FEE_YIELD[m.sector] * (1 - 0.15 * (m.steady_value > 300_000)) \
                     * RNG.normal(1.0, 0.03)

            rows.append({"merchant_id": m.merchant_id, "month": str(per),
                         "txn_count": txn_count,
                         "txn_value_gbp": round(value, 2),
                         "declined_count": declined,
                         "fee_revenue_gbp": round(value * yield_, 2)})
    return pd.DataFrame(rows)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    merchants = build_merchants()
    monthly = build_monthly(merchants)

    out = merchants.copy()
    out["onboarded_month"] = out.onboarded_month.astype(str)
    out["churn_month"] = out.churn_month.astype(str).replace({"NaT": "", "<NA>": ""})
    out["status"] = np.where(out.churn_month == "", "Active", "Churned")
    out = out.drop(columns=["steady_value", "at_risk"])
    out.to_csv(os.path.join(OUT_DIR, "merchants.csv"), index=False)
    monthly.to_csv(os.path.join(OUT_DIR, "monthly_metrics.csv"), index=False)

    print(f"merchants       : {len(out):>6,} rows  ({(out.status == 'Churned').sum()} churned)")
    print(f"monthly_metrics : {len(monthly):>6,} rows")
    print(f"written to {OUT_DIR}")


if __name__ == "__main__":
    main()
