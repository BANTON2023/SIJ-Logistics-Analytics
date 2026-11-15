# SQL — answering the business questions in PostgreSQL

The same 16 business questions the Power BI report answers, written as SQL against
the raw CSV data. Use it to check the report, to answer questions the report does
not show (for example ranked lists for follow-up), or to run the analysis without
Power BI.

| File | Contents |
| --- | --- |
| `01_schema.sql` | Tables, keys and indexes (schema `sij`), one table per CSV file |
| `02_load.sql` | Loads the CSV files with `\copy` |
| `questions/00_reconciliation.sql` | Headline KPIs calculated like the Power BI measures |
| `questions/01_customers.sql` | Q1–Q4: concentration, revenue per load, potential, active vs inactive |
| `questions/02_fleet.sql` | Q5–Q8: utilization, maintenance cost, MPG and idle, driver experience |
| `questions/03_service.sql` | Q9–Q12: on-time, detention, transit times, safety |
| `questions/04_cost.sql` | Q13–Q16: cost trend, cost mix, margin by route and customer, fuel price |

Each query starts with a comment giving its question number (`Q1`, `Q6b`, …) and
any assumption it makes. Answers and their report locations are in
[`../docs/Business_Questions.md`](../docs/Business_Questions.md).

## Run in PostgreSQL

Needs PostgreSQL 14 or later and `psql`.

```powershell
createdb sij_logistics
psql -d sij_logistics -f sql/01_schema.sql
cd "<folder with the CSV files>"
psql -d sij_logistics -f "<repo>/sql/02_load.sql"
psql -d sij_logistics -f "<repo>/sql/questions/01_customers.sql"
```

## Check without a database server

`tools/verify_sql.py` loads the CSV files into an in-memory SQLite database with the
same layout, checks every foreign key, runs every query, and compares the
reconciliation query with the Power BI figures. It uses only the Python standard
library.

```powershell
python tools/verify_sql.py "<folder with the CSV files>"
```

It prints each query's first rows and ends with `RESULT: PASS` when all queries run,
all foreign keys are valid and all 14 headline KPIs match Power BI.

## Conventions

- Definitions match the Power BI measures: for example On-Time % = on-time stops /
  all stops, Avg MPG = total miles / total gallons, Cost per Mile = (fuel +
  maintenance) / trip miles.
- Trip-level costs (fuel, claims) are dated by the load date, as in the model.
- Percentages are returned as 0–100 and rounded for reading; ratios use `100.0 *`
  to avoid integer division.
- Customers are grouped by `customer_id`: 200 accounts share 107 names.
