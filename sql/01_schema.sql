-- =============================================================================
-- SIJ Logistics & Analytics - database schema (PostgreSQL 14+)
--
-- One table per source CSV file, in schema "sij". Column names match the CSV
-- headers, so the files load without mapping. Run this file first, then
-- 02_load.sql, then the question files in sql/questions/.
--
--   psql -d sij_logistics -f sql/01_schema.sql
-- =============================================================================

DROP SCHEMA IF EXISTS sij CASCADE;
CREATE SCHEMA sij;

-- ---------------------------------------------------------------- dimensions

CREATE TABLE sij.customers (
    customer_id              TEXT PRIMARY KEY,
    customer_name            TEXT NOT NULL,
    customer_type            TEXT,           -- Contract, Spot, Dedicated
    credit_terms_days        INTEGER,
    primary_freight_type     TEXT,
    account_status           TEXT,           -- Active, Inactive
    contract_start_date      DATE,
    annual_revenue_potential NUMERIC(14,2)   -- customer's stated yearly freight budget
);

CREATE TABLE sij.drivers (
    driver_id          TEXT PRIMARY KEY,
    first_name         TEXT,
    last_name          TEXT,
    hire_date          DATE,
    termination_date   DATE,
    license_number     TEXT,
    license_state      TEXT,
    date_of_birth      DATE,
    home_terminal      TEXT,
    employment_status  TEXT,
    cdl_class          TEXT,
    years_experience   INTEGER
);

CREATE TABLE sij.trucks (
    truck_id               TEXT PRIMARY KEY,
    unit_number            TEXT,
    make                   TEXT,
    model_year             INTEGER,
    vin                    TEXT,
    acquisition_date       DATE,
    acquisition_mileage    INTEGER,
    fuel_type              TEXT,
    tank_capacity_gallons  INTEGER,
    status                 TEXT,
    home_terminal          TEXT
);

CREATE TABLE sij.trailers (
    trailer_id        TEXT PRIMARY KEY,
    trailer_number    TEXT,
    trailer_type      TEXT,
    length_feet       INTEGER,
    model_year        INTEGER,
    vin               TEXT,
    acquisition_date  DATE,
    status            TEXT,
    current_location  TEXT
);

CREATE TABLE sij.facilities (
    facility_id      TEXT PRIMARY KEY,
    facility_name    TEXT,
    facility_type    TEXT,                   -- Terminal, Warehouse, Cross-Dock, Distribution Center
    city             TEXT,
    state            TEXT,
    latitude         NUMERIC(9,6),
    longitude        NUMERIC(9,6),
    dock_doors       INTEGER,
    operating_hours  TEXT
);

CREATE TABLE sij.routes (
    route_id                TEXT PRIMARY KEY,
    origin_city             TEXT,
    origin_state            TEXT,
    destination_city        TEXT,
    destination_state       TEXT,
    typical_distance_miles  INTEGER,
    base_rate_per_mile      NUMERIC(8,2),
    fuel_surcharge_rate     NUMERIC(8,2),
    typical_transit_days    INTEGER          -- planned transit time
);

-- --------------------------------------------------------------------- facts

CREATE TABLE sij.loads (
    load_id              TEXT PRIMARY KEY,
    customer_id          TEXT REFERENCES sij.customers (customer_id),
    route_id             TEXT REFERENCES sij.routes (route_id),
    load_date            DATE NOT NULL,
    load_type            TEXT,               -- Dry Van, Refrigerated
    weight_lbs           INTEGER,
    pieces               INTEGER,
    revenue              NUMERIC(12,2),      -- base line-haul revenue
    fuel_surcharge       NUMERIC(12,2),
    accessorial_charges  NUMERIC(12,2),      -- extra charges, e.g. detention
    load_status          TEXT,
    booking_type         TEXT
);

-- truck_id is empty on about 2% of trips in the source data, so it is nullable.
CREATE TABLE sij.trips (
    trip_id                TEXT PRIMARY KEY,
    load_id                TEXT REFERENCES sij.loads (load_id),
    driver_id              TEXT REFERENCES sij.drivers (driver_id),
    truck_id               TEXT REFERENCES sij.trucks (truck_id),
    trailer_id             TEXT REFERENCES sij.trailers (trailer_id),
    dispatch_date          DATE,
    actual_distance_miles  INTEGER,
    actual_duration_hours  NUMERIC(8,2),
    fuel_gallons_used      NUMERIC(10,2),
    average_mpg            NUMERIC(6,2),
    idle_time_hours        NUMERIC(8,2),
    trip_status            TEXT
);

-- One pickup and one delivery event per load.
CREATE TABLE sij.delivery_events (
    event_id            TEXT PRIMARY KEY,
    load_id             TEXT REFERENCES sij.loads (load_id),
    trip_id             TEXT REFERENCES sij.trips (trip_id),
    event_type          TEXT,                -- Pickup, Delivery
    facility_id         TEXT REFERENCES sij.facilities (facility_id),
    scheduled_datetime  TIMESTAMP,
    actual_datetime     TIMESTAMP,
    detention_minutes   INTEGER,             -- waiting time at the dock
    on_time_flag        BOOLEAN,             -- within 2 hours of the appointment
    location_city       TEXT,
    location_state      TEXT
);

CREATE TABLE sij.fuel_purchases (
    fuel_purchase_id  TEXT PRIMARY KEY,
    trip_id           TEXT REFERENCES sij.trips (trip_id),
    truck_id          TEXT REFERENCES sij.trucks (truck_id),
    driver_id         TEXT REFERENCES sij.drivers (driver_id),
    purchase_date     TIMESTAMP,
    location_city     TEXT,
    location_state    TEXT,
    gallons           NUMERIC(10,2),
    price_per_gallon  NUMERIC(8,3),
    total_cost        NUMERIC(12,2),
    fuel_card_number  TEXT
);

CREATE TABLE sij.maintenance_records (
    maintenance_id       TEXT PRIMARY KEY,
    truck_id             TEXT REFERENCES sij.trucks (truck_id),
    maintenance_date     DATE,
    maintenance_type     TEXT,
    odometer_reading     INTEGER,
    labor_hours          NUMERIC(8,2),
    labor_cost           NUMERIC(12,2),
    parts_cost           NUMERIC(12,2),
    total_cost           NUMERIC(12,2),
    facility_location    TEXT,
    downtime_hours       NUMERIC(8,2),
    service_description  TEXT
);

CREATE TABLE sij.safety_incidents (
    incident_id          TEXT PRIMARY KEY,
    trip_id              TEXT REFERENCES sij.trips (trip_id),
    truck_id             TEXT REFERENCES sij.trucks (truck_id),
    driver_id            TEXT REFERENCES sij.drivers (driver_id),
    incident_date        TIMESTAMP,
    incident_type        TEXT,
    location_city        TEXT,
    location_state       TEXT,
    at_fault_flag        BOOLEAN,
    injury_flag          BOOLEAN,
    vehicle_damage_cost  NUMERIC(12,2),
    cargo_damage_cost    NUMERIC(12,2),
    claim_amount         NUMERIC(12,2),      -- vehicle + cargo damage
    preventable_flag     BOOLEAN,
    description          TEXT
);

CREATE TABLE sij.driver_monthly_metrics (
    driver_id              TEXT REFERENCES sij.drivers (driver_id),
    month                  DATE,
    trips_completed        INTEGER,
    total_miles            INTEGER,
    total_revenue          NUMERIC(12,2),
    average_mpg            NUMERIC(6,2),
    total_fuel_gallons     NUMERIC(10,2),
    on_time_delivery_rate  NUMERIC(5,3),
    average_idle_hours     NUMERIC(8,2),
    PRIMARY KEY (driver_id, month)
);

CREATE TABLE sij.truck_utilization_metrics (
    truck_id            TEXT REFERENCES sij.trucks (truck_id),
    month               DATE,
    trips_completed     INTEGER,
    total_miles         INTEGER,
    total_revenue       NUMERIC(12,2),
    average_mpg         NUMERIC(6,2),
    maintenance_events  INTEGER,
    maintenance_cost    NUMERIC(12,2),
    downtime_hours      NUMERIC(8,2),
    utilization_rate    NUMERIC(6,3),       -- fraction; can exceed 1.0
    PRIMARY KEY (truck_id, month)
);

-- ------------------------------------------------------------------- indexes
-- Foreign-key columns used in joins by the question queries.
CREATE INDEX ix_loads_customer      ON sij.loads (customer_id);
CREATE INDEX ix_loads_route         ON sij.loads (route_id);
CREATE INDEX ix_trips_load          ON sij.trips (load_id);
CREATE INDEX ix_trips_truck         ON sij.trips (truck_id);
CREATE INDEX ix_trips_driver        ON sij.trips (driver_id);
CREATE INDEX ix_events_load         ON sij.delivery_events (load_id);
CREATE INDEX ix_events_facility     ON sij.delivery_events (facility_id);
CREATE INDEX ix_fuel_trip           ON sij.fuel_purchases (trip_id);
CREATE INDEX ix_maintenance_truck   ON sij.maintenance_records (truck_id);
CREATE INDEX ix_incidents_trip      ON sij.safety_incidents (trip_id);
