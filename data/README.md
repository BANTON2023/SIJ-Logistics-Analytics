# Data

Fictional operating data for a US trucking company, January 2022 to December 2024,
used for training and portfolio purposes. All names, licence numbers, VINs and fuel
card numbers are made up; no real people or vehicles are described.

| File | Rows | One row per |
| --- | ---: | --- |
| `customers.csv` | 200 | Customer account |
| `drivers.csv` | 150 | Driver |
| `trucks.csv` | 120 | Truck |
| `trailers.csv` | 180 | Trailer |
| `facilities.csv` | 50 | Pickup or delivery site |
| `routes.csv` | 58 | Origin–destination lane |
| `loads.csv` | 85,410 | Shipment booked by a customer |
| `trips.csv` | 85,410 | Truck journey carrying a load |
| `delivery_events.csv` | 170,820 | Pickup or delivery stop |
| `fuel_purchases.csv` | 196,442 | Fuel purchase |
| `maintenance_records.csv` | 2,920 | Maintenance job |
| `safety_incidents.csv` | 170 | Safety incident |
| `driver_monthly_metrics.csv` | 4,464 | Driver per month |
| `truck_utilization_metrics.csv` | 3,312 | Truck per month |

The files are kept exactly as delivered (`.gitattributes` marks them `-text`).

## How the report and SQL use them

- **Power BI** reads them through the `DataSource` parameter. By default it downloads
  them from this folder on GitHub, so the report refreshes on any computer. To work
  offline, set `DataSource` to a local folder ending in `\`, for example
  `C:\Projects\SIJ-Logistics-Analytics\data\` (Power BI Desktop: *Transform data ›
  Edit parameters*).
- **SQL**: `sql/02_load.sql` loads them into PostgreSQL, and `tools/verify_sql.py`
  loads them into SQLite to test the queries.

## Known data-quality issues

Found while building the report; see `docs/Business_Questions.md`.

- 200 customer accounts share only 107 names (7 accounts are called "First Group").
- 1,672 trips (2%) have no truck recorded.
- Customers marked "Inactive" still book about $14M of loads a year.
- Fuel purchases per trip do not follow trip length, so short routes such as
  New York–Philadelphia show fuel costs above revenue.
- There is no driver pay, insurance or overhead data, so profit is overstated.
