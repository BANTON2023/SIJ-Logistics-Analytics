# Changelog

All notable changes to this project are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.1] - 2026-11-16

Final release: the project is complete.

### Added

- Screenshots of all six report pages in `docs/images/`, shown in the README.

### Fixed

- Refresh from GitHub timed out on slow connections: each CSV download now allows
  up to 30 minutes instead of Power BI's 100-second default (the largest file,
  `fuel_purchases.csv`, is 20 MB, roughly 4 MB compressed).

## [1.0.0] - 2026-11-15

First complete release.

### Added

- **Semantic model** (TMDL): star schema with a shared `Calendar` table and 155
  measures in display folders, including business-question measures for customers,
  fleet, service and cost.
- **KPI cards with targets and year-on-year comparison**: every KPI shows its change
  against the previous year (green when good, red when bad) and, where set, its target,
  with the value coloured by whether the target is met. KPI definitions live in
  `tools/kpi_catalog.json`; `tools/build_kpi_measures.ps1` generates the measures.
- **On-time split** following industry practice: On-Time Pickup %, On-Time Delivery %,
  Late Stops % and Early Stops %.
- **Report** (PBIR): Executive Overview, Customers, Fleet, Service, Cost and Summary &
  Actions pages, with sidebar navigation, synced date slicers, page slicers, a Clear all
  filters button and the custom `SIJ Logistics & Analytics` theme.
- **Online data source**: the 14 source CSV files are in `data/`, and every table reads
  them through the `DataSource` parameter (this repository on GitHub by default, or a
  local folder), so the report refreshes on any computer.
- **SQL** (PostgreSQL): schema with keys and indexes, a load script, a reconciliation
  query and queries answering all 16 business questions.
- **SQL test**: `tools/verify_sql.py` runs every query against the CSV files in SQLite,
  checks every foreign key and fails unless 14 headline KPIs match Power BI.
- **Documentation**: README, executive summary, question-by-question answers, data
  dictionary with known data-quality issues, MIT licence and this changelog.

### Changed

- Executive Overview shows Margin after Fuel % instead of Profit Margin %, which was
  overstated because the data has no driver pay or overheads.
- Service KPIs use the on-time split instead of one combined on-time rate.
- Customer scorecard shows one row per account (200 accounts share 107 names).

### Fixed

- Report formatting objects written as arrays, as the PBIR schema requires.
- Navigation button labels and dropdown slicers sized so they render and work.
- Sidebar panels ignored their colour and showed the theme blue; shape fill now uses
  the required `default` selector, so the grey filter panel renders.
- KPI comparisons show "No change" instead of "▲ 0.0%" when a value is unchanged.
- Fuel share and customer concentration figures corrected after SQL reconciliation.

[Unreleased]: ../../compare/v1.0.1...HEAD
[1.0.1]: ../../compare/v1.0.0...v1.0.1
[1.0.0]: ../../releases/tag/v1.0.0
