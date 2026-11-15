# SIJ Logistics & Analytics

**Transport and freight performance reporting in Power BI and PostgreSQL**

[![License: MIT](https://img.shields.io/badge/License-MIT-teal.svg)](LICENSE)
![Power BI](https://img.shields.io/badge/Power%20BI-PBIP%20%2F%20TMDL%20%2F%20PBIR-F2C811)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14%2B-336791)
![Data](https://img.shields.io/badge/data-2022--2024-1F4E79)

A capstone analytics project for a US trucking company. A Power BI report and a set of
SQL queries answer 16 business questions about **customers**, **fleet**, **service**
and **cost**, using three years of operating data (85,410 loads, 122 million miles).

Author: **Mbaji Austin** · Licence: [MIT](LICENSE) · Changes: [CHANGELOG](CHANGELOG.md)

---

## Screenshots

<!-- Screenshots of each report page go in docs/images/ and are listed here. -->

_Screenshots of the six report pages will be added here._

---

## Key insights

| | Finding | Action |
| --- | --- | --- |
| 🚚 | **Only 45% of deliveries arrive on time**, and 9,382 stops marked late actually arrived over 2 hours early. Appointment times are not set from real drive times. | Plan appointments from actual transit times; target 75% on time. |
| ⏱️ | **Drivers wait 92 minutes per stop**; 49,800 hours of waiting went beyond a 2-hour allowance. | Bill detention after 2 hours: about **$3.7M** over three years. |
| ⛽ | **Fuel is 94% of operating cost**, and engines idle for 28% of trip time. | Idle limits and driver coaching: about **$0.9M** over three years. |
| 📈 | **We win only 16% of customers' stated freight potential.** | Target the 36 accounts below 10%; win back 32 inactive accounts. |
| 🦺 | **170 safety incidents**, 38% preventable, $2.65M in claims; 18 drivers had 3 or more. | Coach the high-risk drivers first. |

Full write-ups: [Executive summary](docs/Executive_Summary.md) ·
[All 16 questions answered](docs/Business_Questions.md)

---

## Quick start

**Power BI report**

1. Clone or download this repository.
2. Open `TSA_capstone.pbip` in Power BI Desktop (current release).
3. Select **Refresh**. The data downloads from this repository's `data/` folder, so
   nothing needs to be set up. If Power BI asks about privacy levels, choose **Public**.

To work offline, set the `DataSource` parameter (*Transform data › Edit parameters*)
to your local `data\` folder, ending in `\`.

**SQL**

```powershell
python tools/verify_sql.py          # runs every query on the CSVs and checks them against Power BI
```

Or load the data into PostgreSQL: see [`sql/README.md`](sql/README.md).

---

## Repository layout

| Path | Contents |
| --- | --- |
| `TSA_capstone.pbip` | Power BI project: open this in Power BI Desktop |
| `TSA_capstone.SemanticModel/` | Data model in TMDL: tables, relationships, 155 measures, `DataSource` parameter |
| `TSA_capstone.Report/` | Report pages and visuals in PBIR (JSON), and the custom theme |
| `data/` | The 14 source CSV files ([data dictionary and known issues](data/README.md)) |
| `sql/` | PostgreSQL schema, load script and queries for the 16 questions ([details](sql/README.md)) |
| `docs/` | Executive summary and question-by-question answers |
| `tools/build_report_pages.ps1` | Generates the report pages |
| `tools/build_kpi_measures.ps1` | Generates the KPI comparison and target measures |
| `tools/kpi_catalog.json` | KPI titles, targets and which direction is good |
| `tools/verify_sql.py` | Tests the SQL and reconciles it with Power BI (standard-library Python) |
| `TSA_capstone_new_measures.dax` | Readable list of the business-question measures |

---

## Data model

Star schema with a shared `Calendar` date table (2022–2024).

- **Facts:** `loads`, `trips`, `delivery_events`, `fuel_purchases`, `maintenance_records`,
  `safety_incidents`, `driver_monthly_metrics`, `truck_utilization_metrics`
- **Dimensions:** `customers`, `routes`, `facilities`, `drivers`, `trucks`, `trailers`, `Calendar`

Design choices:

- **Dates:** `Calendar` filters `loads[load_date]`, `maintenance_records[maintenance_date]`
  and the two monthly metric tables. Trips, fuel, incidents and deliveries follow the
  load date through `loads → trips`. `trips[dispatch_date]` has an inactive link for
  `USERELATIONSHIP`.
- **`trips ↔ loads`** is one-to-one and filters both ways, so driver and truck filters
  reach revenue, and customer and route filters reach trip-level facts. All other
  relationships filter one way.
- **Data source:** every table reads from the `DataSource` parameter (web address or
  local folder), so the model is not tied to one computer.

### Measures

All measures are in the `_Measures` table, in display folders:

| Folder | Examples |
| --- | --- |
| Revenue & Volume | Total Revenue, Total Billed Revenue, Avg Revenue per Load, Revenue vs Potential % |
| Operations | Total Loads, Total Trips, Total Miles, Avg Trip Duration (hrs) |
| Fleet | Avg MPG, Idle %, Avg Utilization Rate, Downtime Hours, Active Trucks |
| Service | On-Time Delivery %, On-Time Pickup %, Late Stops %, Early Stops %, Avg Detention (min) |
| Safety | Total Safety Incidents, Incidents per 100 Trips, Preventable Incident % |
| Costs | Total Operating Cost, Cost per Mile, Avg Fuel Price per Gallon, Margin after Fuel |
| KPI Comparison | `<KPI> vs LY` text and `<KPI> vs LY Color` for every KPI card |
| KPI Targets | `<KPI> Target` and `<KPI> Target Color` |

**Limitations:** operating cost covers **fuel and maintenance only**; the data has no
driver pay, insurance or overheads, so margins are overstated. Maintenance is linked to
trucks, not loads, so customers and routes are compared on `Margin after Fuel`.

---

## Report

Six pages: **Executive Overview**, **Customers**, **Fleet**, **Service**, **Cost** and
**Summary & Actions**, in the custom `SIJ Logistics & Analytics` theme.

- **Sidebar:** brand banner, navigation buttons for every page (current page in teal),
  and a grey filter panel with Year, Quarter and Month (synced across pages), two
  page-specific slicers and **Clear all filters**.
- **KPI cards:** six per page. Each shows the value (green when it meets its target,
  red when it misses), the change against the previous year (for example
  `2024: ▲ 1.2 pts vs 2023`, green when the change is good), and the target.
  With several years selected, the comparison is the latest selected year against
  the year before. Targets are management assumptions set in
  [`tools/kpi_catalog.json`](tools/kpi_catalog.json).
- **Charts and tables** for each question below the KPI cards.

KPI titles marked `*` use operating cost (fuel and maintenance only).

### Changing the report

The pages and KPI measures are generated from scripts, so design changes are made in
the scripts, not by hand. Close Power BI Desktop, then:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_kpi_measures.ps1 -Repo .   # after editing kpi_catalog.json
powershell -ExecutionPolicy Bypass -File tools\build_report_pages.ps1 -Repo .   # after editing the page layout
```

| To change | Edit |
| --- | --- |
| KPI titles, targets, good direction | `tools/kpi_catalog.json`, then run both scripts |
| Which KPIs a page shows | The `Kpis` line for that page in `build_report_pages.ps1` |
| Colours | `SIJ_Logistics_Theme.json` and the palette variables at the top of `build_report_pages.ps1` |
| Page titles, slicers, charts | The `Page`, `Slicers` and `Visual` lines for that page |
| Sizes and spacing | The layout variables (`$HEAD_H`, `$R1_Y`, `$KPI_W`, …) |

---

## Business questions

Answered one by one, with the report page, visual, measures and SQL query for each, in
[`docs/Business_Questions.md`](docs/Business_Questions.md).

- **Customers:** revenue concentration; revenue per load by type; revenue against
  potential; active versus inactive accounts.
- **Fleet:** utilization and downtime by make and model year; maintenance cost per truck
  and per mile; MPG and idle time; driver experience.
- **Service:** on-time pickup and delivery; detention; actual against planned transit
  time; safety incidents and claims.
- **Cost:** cost per load and per mile over time; cost mix; margin by route and customer;
  fuel price by state.

---

## Contributing

`main` is protected by convention: every change goes through a pull request.

1. Create a branch: `feat/…`, `fix/…`, `docs/…` or `chore/…`.
2. Close Power BI Desktop before editing files in the PBIP folders or running the scripts.
3. Run the checks: `python tools/verify_sql.py` must end with `RESULT: PASS`.
4. Commit with [Conventional Commits](https://www.conventionalcommits.org/) messages, one
   logical change per commit.
5. Open a pull request, describe what changed and how it was checked, and merge after review.
6. Releases are tagged `vMAJOR.MINOR.PATCH` and recorded in [CHANGELOG.md](CHANGELOG.md).

## Licence

Code and documentation: [MIT](LICENSE). The data in `data/` is fictional training data.
