# 03 — Warehouse KPI Dashboard

Operational dashboard tracking pick accuracy, order fulfilment, lead times, and labour productivity — designed for the warehouse floor, not the boardroom.

## The Business Question

> *Can a warehouse supervisor walk in at 7am, look at one screen, and know what to fix today?*

This dashboard is built to that brief. It draws on my own experience as a Warehouse Manager at Nervi Distributions, where the gap between "report exists" and "report gets used" usually came down to one thing: whether the dashboard answered the questions a supervisor actually asks.

## KPIs Tracked

- Order fulfilment rate (OTIF)
- Pick accuracy
- Average pick time
- Inbound vs outbound throughput
- Stock accuracy (cycle count variance)
- Labour productivity (units per hour)

## Stack

- **SQL** — KPI logic against a simulated WMS schema
- **Power BI** — operational dashboard

## Files

- [`sql/`](./sql)
- [`dashboards/`](./dashboards)
- [`images/`](./images)
