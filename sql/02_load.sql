-- =============================================================================
-- SIJ Logistics & Analytics - load the source CSV files (PostgreSQL, psql)
--
-- Run from the folder that holds the CSV files, because \copy paths are
-- relative to where psql is started:
--
--   cd "<folder with the CSV files>"
--   psql -d sij_logistics -f "<repo>/sql/02_load.sql"
--
-- Tables load in dependency order (dimensions first) so foreign keys hold.
-- In CSV format, empty fields load as NULL; "True"/"False" load as BOOLEAN.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

\copy sij.customers                 FROM 'customers.csv'                 WITH (FORMAT csv, HEADER true)
\copy sij.drivers                   FROM 'drivers.csv'                   WITH (FORMAT csv, HEADER true)
\copy sij.trucks                    FROM 'trucks.csv'                    WITH (FORMAT csv, HEADER true)
\copy sij.trailers                  FROM 'trailers.csv'                  WITH (FORMAT csv, HEADER true)
\copy sij.facilities                FROM 'facilities.csv'                WITH (FORMAT csv, HEADER true)
\copy sij.routes                    FROM 'routes.csv'                    WITH (FORMAT csv, HEADER true)
\copy sij.loads                     FROM 'loads.csv'                     WITH (FORMAT csv, HEADER true)
\copy sij.trips                     FROM 'trips.csv'                     WITH (FORMAT csv, HEADER true)
\copy sij.delivery_events           FROM 'delivery_events.csv'           WITH (FORMAT csv, HEADER true)
\copy sij.fuel_purchases            FROM 'fuel_purchases.csv'            WITH (FORMAT csv, HEADER true)
\copy sij.maintenance_records       FROM 'maintenance_records.csv'       WITH (FORMAT csv, HEADER true)
\copy sij.safety_incidents          FROM 'safety_incidents.csv'          WITH (FORMAT csv, HEADER true)
\copy sij.driver_monthly_metrics    FROM 'driver_monthly_metrics.csv'    WITH (FORMAT csv, HEADER true)
\copy sij.truck_utilization_metrics FROM 'truck_utilization_metrics.csv' WITH (FORMAT csv, HEADER true)

COMMIT;

ANALYZE;

-- Row counts after loading
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM sij.customers
UNION ALL SELECT 'loads', COUNT(*) FROM sij.loads
UNION ALL SELECT 'trips', COUNT(*) FROM sij.trips
UNION ALL SELECT 'delivery_events', COUNT(*) FROM sij.delivery_events
UNION ALL SELECT 'fuel_purchases', COUNT(*) FROM sij.fuel_purchases
UNION ALL SELECT 'maintenance_records', COUNT(*) FROM sij.maintenance_records
UNION ALL SELECT 'safety_incidents', COUNT(*) FROM sij.safety_incidents;
