# SIJ Logistics & Analytics — Transport and Freight Reporting (Power BI)

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
| `docs/Executive_Summary.md` | Plain-language findings and recommendations for management |
| `docs/Business_Questions.md` | Each business question, where the report answers it, and the answer |
| `sql/` | PostgreSQL schema, CSV load script and queries answering the 16 questions ([details](sql/README.md)) |
| `tools/verify_sql.py` | Runs all SQL against the CSV files and reconciles the totals with Power BI |

There is no `.pbix` in this project: `TSA_capstone.pbip` and its folders are the only
working copy. (`.pbix` files are also ignored by Git.)

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

Six pages: **Executive Overview**, **Customers**, **Fleet**, **Service**, **Cost** and
**Summary & Actions**, styled with the custom `SIJ Logistics & Analytics` theme
(`TSA_capstone.Report/StaticResources/RegisteredResources/SIJ_Logistics_Theme.json`):
teal and navy palette, white rounded cards with a soft shadow, light grey canvas.

Every page shares one layout:

- **Title bar (top):** full-width white bar with the page title in bold and a
  one-line description.
- **Sidebar (left)**
  - White panel with the brand and **navigation buttons** labelled with each page's
    title; the current page is solid teal, the others light grey (pale teal on hover).
    Click to switch pages (Ctrl+click while editing in Power BI Desktop).
  - Grey **filter panel** down to the bottom edge: Year, Quarter and Month dropdowns,
    synced across all pages so a date selection carries over, plus two slicers for the
    page's own categories (for example Customer Type and Account Status on Customers),
    and a **Clear all filters** button. Each slicer shows its name once.
- **Main area:** 12 px margins on every side.
  - **Six KPI cards** in a 3 × 2 block beside the page's lead chart.
  - Detail charts and scorecard tables below.

KPI titles marked `*` use operating cost, which covers fuel and maintenance only.

**Summary & Actions** lists the main findings and seven recommendations in plain
language. Its figures are fixed text for the full 2022–2024 period and do not respond
to filters; the full write-up is in [`docs/Executive_Summary.md`](docs/Executive_Summary.md).
Update both together when the data changes.

### Customising the report

The pages are generated by `tools/build_report_pages.ps1`. Close Power BI Desktop,
edit the script, run it, then reopen the project:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_report_pages.ps1 -Repo .
```

| To change | Edit |
| --- | --- |
| Colours for the whole report | `dataColors` and `visualStyles` in `SIJ_Logistics_Theme.json`, and the palette variables (`$TEAL`, `$INK`, `$BTN_GREY`, …) at the top of the script |
| A page title or description | The `Page` line for that page |
| Which KPIs a page shows | The `Kpis` line: list of measure names, then the card titles |
| A page's category slicers | The `Slicers` line: table, column and label |
| A chart's fields or title | The `Visual` lines for that page |
| Sizes and spacing | The layout variables (`$HEAD_H`, `$R1_Y`, `$KPI_W`, …) |
| Pages in the sidebar | `$PAGE_LIST` |

Re-running the script replaces every generated visual. Changes made by hand in
Power BI Desktop to those visuals are overwritten, so either make design changes in
the script, or stop using the script and edit in Desktop from then on.

## Business questions

Answered question by question, with the report page, visual and measures for each, in
[`docs/Business_Questions.md`](docs/Business_Questions.md).

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
