# SIJ_Logistics — Transport & Logistics Analytics (Power BI)

Capstone analytics project for a trucking and freight operation. A Power BI
semantic model and report answer business questions about **customers**,
**fleet**, **service** and **cost**, using 2022–2024 operating data.

Author: Mbaji Austin

## Repository layout

| Path | Contents |
| --- | --- |
| `TSA_capstone.pbip` | Power BI project file — open this in Power BI Desktop |
| `TSA_capstone.SemanticModel/` | Data model in TMDL: tables, measures, relationships |
| `TSA_capstone.Report/` | Report pages and visuals in PBIR (JSON) |
| `TSA_capstone_new_measures.dax` | Readable list of the business-question measures |
| `tools/build_report_pages.ps1` | Regenerates the report pages (close Power BI Desktop first) |

Binary `.pbix` files are not tracked; the PBIP folders are the source of truth.

## Data model

Star-style model with a shared `Calendar` date table (2022–2024).

**Fact tables:** `loads`, `trips`, `delivery_events`, `fuel_purchases`,
`maintenance_records`, `safety_incidents`, `driver_monthly_metrics`,
`truck_utilization_metrics`

**Dimension tables:** `customers`, `routes`, `facilities`, `drivers`,
`trucks`, `trailers`, `Calendar`

Key design choices:

- **Dates:** `Calendar` filters `loads[load_date]`, `maintenance_records[maintenance_date]`
  and the two monthly metric tables. Trips, fuel, incidents and deliveries follow
  the load date through `loads → trips`. `trips[dispatch_date]` has an inactive link;
  use `USERELATIONSHIP(trips[dispatch_date], 'Calendar'[Date])` to report by dispatch date.
- **`trips ↔ loads`** is one-to-one and filters both ways, so driver and truck
  filters reach revenue and customer and route filters reach trip-level facts.
  All other relationships filter one way.
- **Auto date/time is off.** Use `Calendar` for all date grouping.

## Measures

All measures live in the `_Measures` table, in display folders:

| Folder | Examples |
| --- | --- |
| Revenue & Volume | Total Revenue, Total Billed Revenue, Avg Revenue per Load, Customer Revenue Share % |
| Operations | Total Loads, Total Trips, Total Miles, Avg Trip Duration (hrs) |
| Fleet | Avg MPG, Idle %, Avg Utilization Rate, Downtime Hours, Active Trucks |
| Service | On-Time %, Avg Detention (min), Avg Actual vs Planned Transit Days |
| Safety | Total Safety Incidents, Incidents per 100 Trips, Preventable Incident %, Total Claim Amount |
| Costs | Total Operating Cost, Cost per Mile, Avg Fuel Price per Gallon, Profit, Margin after Fuel |

**Limitations**

- Operating cost covers **fuel and maintenance only**. The data has no driver pay,
  insurance or overheads, so profit and margin are overstated against real
  operations.
- `Profit` and `Profit Margin %` are valid for the whole company or by time period.
  Maintenance is linked to trucks, not loads, so use `Margin after Fuel` when
  breaking down by customer or route.

## Report

Five pages: **Executive Overview**, **Customers**, **Fleet**, **Service** and **Cost**.
Every page uses the same layout, top to bottom:

1. **Navigation bar** — a page navigator listing all five pages, with the current
   page highlighted. Click a page name to go there (Ctrl+click in Power BI Desktop).
2. **KPI cards** — six headline measures for the page.
3. **Slicer panel** — Year, Quarter and Month dropdowns, synced across all pages so
   a date selection carries over, plus two slicers for that page's topic.
4. **Charts and scorecard tables** answering the page's business questions.

## Business questions

**Customers** — revenue concentration; revenue per load by customer and freight
type; revenue against annual potential; trends for active and inactive accounts.

**Fleet** — utilization, downtime and miles by truck, make and model year;
maintenance cost per truck and per mile; MPG and idle time by truck and driver;
driver productivity.

**Service** — on-time delivery by customer, facility, route and month; detention
by facility and customer; actual against planned transit times; safety incident
rate, preventable share and claim cost.

**Cost** — operating cost per load and per mile over time; fuel, maintenance and
incident cost mix; margin by customer and route; fuel price by state.

## Working on the project

1. Open `TSA_capstone.pbip` in Power BI Desktop (current release; PBIR and TMDL
   preview features enabled).
2. Make changes and save. Power BI Desktop writes the changes into the text files.
3. Close Power BI Desktop before editing files in the PBIP folders directly.
4. Commit with [Conventional Commits](https://www.conventionalcommits.org/) messages
   (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`), one logical change per commit.
