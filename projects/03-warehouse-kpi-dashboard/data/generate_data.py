"""
Project 03 — Warehouse KPI Dashboard
Simulated WMS dataset generator.

Generates a fully synthetic warehouse operation: ~48 operatives across three
shifts, 12 months of daily pick sessions, order fulfilment records and dock
throughput (Jul 2025 – Jun 2026). Patterns are seeded deliberately so the
dashboard has genuine operational stories to surface:

  * night shift picks less accurately than early/late (supervision and fatigue),
  * new starters are slower AND less accurate for their first ~90 days,
  * accuracy degrades when an operative is pushed above their own normal rate
    (the speed-accuracy trade-off supervisors argue about),
  * Monday fulfilment dips (weekend order backlog hits a cold operation),
  * the Nov/Dec peak lifts volume ~40% and costs accuracy.

These are the shapes I lived with as a Warehouse Manager at Nervi
Distributions; every name, volume and date here is invented. No real company
data is used.

Usage:
    python generate_data.py     # writes CSVs to ./sample/

Reproducible: fixed RNG seed (13).
"""

from __future__ import annotations

import os
from datetime import date, timedelta

import numpy as np
import pandas as pd

RNG = np.random.default_rng(13)

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sample")

START = date(2025, 7, 1)
END = date(2026, 6, 30)

SHIFTS = ["Early", "Late", "Night"]
SHIFT_SIZE = {"Early": 20, "Late": 17, "Night": 11}

# Baseline error rate (mispicks per 1,000 lines) and pick rate (lines/hour)
SHIFT_ERROR_MULT = {"Early": 1.00, "Late": 1.15, "Night": 2.20}
SHIFT_RATE_MULT = {"Early": 1.00, "Late": 0.97, "Night": 0.93}

ZONES = ["Ambient Pick", "Chilled Pick", "Bulk", "Returns"]
ZONE_P = [0.46, 0.24, 0.22, 0.08]
ZONE_RATE = {"Ambient Pick": 78, "Chilled Pick": 62, "Bulk": 44, "Returns": 35}
ZONE_ERROR = {"Ambient Pick": 3.4, "Chilled Pick": 4.1, "Bulk": 2.2, "Returns": 5.0}

FIRST = ["Aaron", "Bethan", "Callum", "Danika", "Ewan", "Farida", "Gareth", "Hollie",
         "Idris", "Jasmine", "Kieran", "Leona", "Marcus", "Nadia", "Owen", "Priya",
         "Quentin", "Rhona", "Samir", "Tessa", "Umar", "Verity", "Wesley", "Yasmin",
         "Zane", "Adaeze", "Blair", "Cerys", "Dominik", "Elowen", "Fionn", "Greta",
         "Hamza", "Isla", "Jorge", "Kasia", "Lorcan", "Mireille", "Niall", "Ottilie",
         "Piotr", "Rosalind", "Sanjay", "Tomasz", "Ugo", "Vinnie", "Wren", "Xanthe"]
LAST = ["Ashworth", "Brennan", "Cavanagh", "Doherty", "Ellery", "Fairbairn", "Gainsford",
        "Hollingworth", "Ingram", "Jarrett", "Kowalski", "Lundy", "Merrifield", "Novak",
        "Ormerod", "Pennington", "Quill", "Radcliffe", "Sowerby", "Thackeray", "Underhill",
        "Vaughan", "Whitlock", "Yeardley"]


def working_days():
    d = START
    while d <= END:
        if d.weekday() != 6:  # closed Sundays
            yield d
        d += timedelta(days=1)


def seasonal(d: date) -> float:
    """Volume multiplier — Nov/Dec peak, January trough."""
    return {11: 1.30, 12: 1.45, 1: 0.88, 7: 1.05, 8: 1.05}.get(d.month, 1.0)


def build_operatives() -> pd.DataFrame:
    rows, used, i = [], set(), 1
    for shift, n in SHIFT_SIZE.items():
        for _ in range(n):
            while True:
                name = f"{RNG.choice(FIRST)} {RNG.choice(LAST)}"
                if name not in used:
                    used.add(name)
                    break
            # a third of the team joined during the window (incl. a peak intake)
            r = RNG.random()
            if r < 0.20:
                hired = START + timedelta(days=int(RNG.integers(120, 300)))
            elif r < 0.33:
                hired = START + timedelta(days=int(RNG.integers(0, 120)))
            else:
                hired = START - timedelta(days=int(RNG.integers(200, 2600)))
            rows.append({
                "operative_id": f"OP-{i:03d}",
                "operative_name": name,
                "shift": shift,
                "hire_date": hired,
                # personal ability, lognormal-ish around 1.0
                "skill": float(np.clip(RNG.normal(1.0, 0.11), 0.72, 1.30)),
                "care": float(np.clip(RNG.normal(1.0, 0.22), 0.55, 1.70)),
            })
            i += 1
    return pd.DataFrame(rows)


def build_pick_sessions(ops: pd.DataFrame) -> pd.DataFrame:
    """One row per operative per working day per zone worked."""
    rows = []
    for d in working_days():
        vol = seasonal(d)
        # Monday carries the weekend backlog
        monday_push = 1.18 if d.weekday() == 0 else 1.0
        for op in ops.itertuples(index=False):
            if op.hire_date > d:
                continue
            if RNG.random() < 0.14:      # rest days, holiday, absence
                continue

            tenure_days = (d - op.hire_date).days
            # new starters ramp over ~90 days
            ramp = min(1.0, 0.55 + 0.45 * tenure_days / 90) if tenure_days < 90 else 1.0
            new_starter_err = 2.5 - 1.5 * min(1.0, tenure_days / 90) if tenure_days < 90 else 1.0

            n_zones = 1 if RNG.random() < 0.72 else 2
            zones = RNG.choice(ZONES, size=n_zones, replace=False, p=ZONE_P)
            hours_total = float(np.clip(RNG.normal(7.6, 0.6), 4.0, 9.5))
            splits = RNG.dirichlet(np.ones(n_zones)) if n_zones > 1 else [1.0]

            for zone, share in zip(zones, splits):
                hours = round(hours_total * share, 2)
                if hours < 0.5:
                    continue

                base_rate = ZONE_RATE[zone] * op.skill * SHIFT_RATE_MULT[op.shift] * ramp
                target_rate = base_rate * vol * monday_push * RNG.normal(1.0, 0.07)
                lines = max(5, int(target_rate * hours))
                units = int(lines * RNG.uniform(1.6, 3.4))

                # push factor: working above own normal rate costs accuracy
                push = target_rate / max(base_rate, 1e-6)
                push_pen = 1.0 + 2.2 * max(0.0, push - 1.05)

                err_per_1000 = (ZONE_ERROR[zone]
                                * SHIFT_ERROR_MULT[op.shift]
                                * op.care
                                * new_starter_err
                                * push_pen
                                * (1.25 if d.month in (11, 12) else 1.0)
                                * RNG.normal(1.0, 0.18))
                errors = RNG.poisson(max(0.0, err_per_1000) * lines / 1000)

                rows.append({
                    "session_date": d,
                    "operative_id": op.operative_id,
                    "zone": zone,
                    "hours_worked": hours,
                    "lines_picked": lines,
                    "units_picked": units,
                    "mispicks": int(errors),
                })
    return pd.DataFrame(rows)


def build_orders(sessions: pd.DataFrame) -> pd.DataFrame:
    """Customer orders with a promised dispatch date and what actually happened."""
    daily_lines = sessions.groupby("session_date").lines_picked.sum()
    rows, seq = [], 1
    for d, lines in daily_lines.items():
        n_orders = max(5, int(lines / 165 * RNG.normal(1.0, 0.05)))
        # Monday: weekend backlog on a cold operation
        monday = d.weekday() == 0
        peak = d.month in (11, 12)
        for _ in range(n_orders):
            promised = d
            p_late = 0.055
            if monday:
                p_late += 0.075
            if peak:
                p_late += 0.035
            late = RNG.random() < p_late
            dispatched = promised + timedelta(days=1 if late else 0)
            lines_ordered = int(np.clip(RNG.lognormal(1.9, 0.7), 1, 90))
            short = RNG.random() < 0.032
            lines_shipped = lines_ordered - (int(RNG.integers(1, max(2, lines_ordered // 4)))
                                             if short else 0)
            rows.append({
                "order_id": f"SO-{seq:06d}",
                "order_date": d,
                "promised_dispatch_date": promised,
                "actual_dispatch_date": dispatched,
                "lines_ordered": lines_ordered,
                "lines_shipped": max(1, lines_shipped),
            })
            seq += 1
    return pd.DataFrame(rows)


def build_throughput(sessions: pd.DataFrame) -> pd.DataFrame:
    out = sessions.groupby("session_date").agg(
        outbound_units=("units_picked", "sum")).reset_index()
    rows = []
    for r in out.itertuples(index=False):
        d = r.session_date
        # inbound broadly tracks outbound but lands unevenly across the week
        wd_mult = {0: 1.35, 1: 1.10, 2: 0.95, 3: 1.00, 4: 1.25, 5: 0.55}[d.weekday()]
        inbound = int(r.outbound_units * 0.92 * wd_mult * RNG.normal(1.0, 0.10))
        rows.append({
            "throughput_date": d,
            "inbound_units": max(0, inbound),
            "outbound_units": int(r.outbound_units),
            "goods_in_hours": round(float(np.clip(RNG.normal(26, 6) * wd_mult, 6, 70)), 1),
        })
    return pd.DataFrame(rows)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    ops = build_operatives()
    sessions = build_pick_sessions(ops)
    orders = build_orders(sessions)
    throughput = build_throughput(sessions)

    ops_out = ops.drop(columns=["skill", "care"])
    ops_out.to_csv(os.path.join(OUT_DIR, "operatives.csv"), index=False)
    sessions.to_csv(os.path.join(OUT_DIR, "pick_sessions.csv"), index=False)
    orders.to_csv(os.path.join(OUT_DIR, "orders.csv"), index=False)
    throughput.to_csv(os.path.join(OUT_DIR, "throughput.csv"), index=False)

    print(f"operatives    : {len(ops_out):>7,} rows")
    print(f"pick_sessions : {len(sessions):>7,} rows")
    print(f"orders        : {len(orders):>7,} rows")
    print(f"throughput    : {len(throughput):>7,} rows")
    print(f"written to {OUT_DIR}")


if __name__ == "__main__":
    main()
