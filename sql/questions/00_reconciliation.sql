-- =============================================================================
-- R1 Reconciliation: headline KPIs, calculated the same way as the Power BI
-- measures in _Measures. Every value must match the report (full period, no
-- filters). tools/verify_sql.py checks this automatically.
-- =============================================================================

-- R1 Headline KPIs (Power BI measure names in comments)
SELECT
    (SELECT COUNT(*) FROM sij.loads)                                        AS total_loads,          -- Total Loads
    (SELECT SUM(revenue) FROM sij.loads)                                    AS total_revenue,        -- Total Revenue
    (SELECT SUM(revenue + fuel_surcharge + accessorial_charges)
       FROM sij.loads)                                                      AS total_billed_revenue, -- Total Billed Revenue
    (SELECT SUM(actual_distance_miles) FROM sij.trips)                      AS total_miles,          -- Total Miles
    (SELECT SUM(actual_distance_miles) / SUM(fuel_gallons_used)
       FROM sij.trips)                                                      AS avg_mpg,              -- Avg MPG
    (SELECT 100.0 * COUNT(*) FILTER (WHERE on_time_flag) / COUNT(*)
       FROM sij.delivery_events)                                            AS on_time_pct,          -- On-Time %
    (SELECT AVG(detention_minutes) FROM sij.delivery_events)                AS avg_detention_min,    -- Avg Detention (min)
    (SELECT SUM(total_cost) FROM sij.fuel_purchases)
      + (SELECT SUM(total_cost) FROM sij.maintenance_records)               AS total_operating_cost, -- Total Operating Cost
    ((SELECT SUM(total_cost) FROM sij.fuel_purchases)
      + (SELECT SUM(total_cost) FROM sij.maintenance_records))
      / (SELECT SUM(actual_distance_miles) FROM sij.trips)                  AS cost_per_mile,        -- Cost per Mile
    (SELECT SUM(total_cost) / SUM(gallons) FROM sij.fuel_purchases)         AS avg_fuel_price,       -- Avg Fuel Price per Gallon
    (SELECT COUNT(*) FROM sij.safety_incidents)                             AS total_incidents,      -- Total Safety Incidents
    (SELECT 100.0 * COUNT(*) FILTER (WHERE preventable_flag) / COUNT(*)
       FROM sij.safety_incidents)                                           AS preventable_pct,      -- Preventable Incident %
    (SELECT SUM(claim_amount) FROM sij.safety_incidents)                    AS total_claims,         -- Total Claim Amount
    (SELECT 100.0 * AVG(utilization_rate)
       FROM sij.truck_utilization_metrics)                                  AS avg_utilization_pct;  -- Avg Utilization Rate
