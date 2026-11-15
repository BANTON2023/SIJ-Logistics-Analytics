-- =============================================================================
-- Fleet: questions 5-8
-- =============================================================================

-- Q5 How do utilization, downtime and miles compare by truck make and model year?
-- Downtime is per truck-month so makes with more trucks are not penalised.
SELECT t.make,
       t.model_year,
       COUNT(DISTINCT u.truck_id)                            AS trucks,
       ROUND((100.0 * AVG(u.utilization_rate))::numeric, 1)  AS avg_utilization_pct,
       ROUND(AVG(u.downtime_hours)::numeric, 1)              AS downtime_hours_per_truck_month,
       SUM(u.total_miles)                                    AS total_miles
FROM sij.truck_utilization_metrics u
JOIN sij.trucks t ON t.truck_id = u.truck_id
GROUP BY t.make, t.model_year
ORDER BY t.make, t.model_year;

-- Q6 Which trucks cost the most to maintain, per truck and per mile?
-- Miles come from trips, as in the Power BI measure "Maintenance Cost per Mile".
-- Some trucks have maintenance records but no trips; their cost per mile is NULL.
WITH maintenance AS (
    SELECT truck_id,
           COUNT(*)                                                     AS jobs,
           COUNT(*) FILTER (WHERE service_description LIKE '%Emergency%') AS emergency_jobs,
           SUM(total_cost)                                              AS maintenance_cost,
           SUM(downtime_hours)                                          AS downtime_hours
    FROM sij.maintenance_records
    GROUP BY truck_id
),
miles AS (
    SELECT truck_id, SUM(actual_distance_miles) AS miles
    FROM sij.trips
    GROUP BY truck_id
)
SELECT t.unit_number,
       t.make,
       t.model_year,
       m.jobs,
       m.emergency_jobs,
       ROUND(m.maintenance_cost::numeric, 2)                              AS maintenance_cost,
       ROUND((m.maintenance_cost / NULLIF(mi.miles, 0))::numeric, 4)      AS cost_per_mile,
       ROUND(m.downtime_hours::numeric, 1)                                AS downtime_hours
FROM maintenance m
JOIN sij.trucks t ON t.truck_id = m.truck_id
LEFT JOIN miles mi ON mi.truck_id = m.truck_id
ORDER BY m.maintenance_cost DESC
LIMIT 15;

-- Q6b Maintenance cost per mile by model year (the Fleet page lead chart)
WITH by_year AS (
    SELECT t.model_year, SUM(m.total_cost) AS cost
    FROM sij.maintenance_records m
    JOIN sij.trucks t ON t.truck_id = m.truck_id
    GROUP BY t.model_year
),
miles AS (
    SELECT t.model_year, SUM(tr.actual_distance_miles) AS miles
    FROM sij.trips tr
    JOIN sij.trucks t ON t.truck_id = tr.truck_id
    GROUP BY t.model_year
)
SELECT b.model_year,
       ROUND(b.cost::numeric, 2)                          AS maintenance_cost,
       ROUND((b.cost / NULLIF(mi.miles, 0))::numeric, 4)  AS cost_per_mile
FROM by_year b
JOIN miles mi ON mi.model_year = b.model_year
ORDER BY cost_per_mile DESC;

-- Q7 How do fuel efficiency (MPG) and idle time compare by truck make and by driver?
-- MPG = miles / gallons (not an average of trip MPGs), as in the Power BI measure.
SELECT 'make' AS level,
       t.make  AS name,
       COUNT(*) AS trips,
       ROUND((SUM(tr.actual_distance_miles) / SUM(tr.fuel_gallons_used))::numeric, 2)   AS mpg,
       ROUND((100.0 * SUM(tr.idle_time_hours) / SUM(tr.actual_duration_hours))::numeric, 1) AS idle_pct
FROM sij.trips tr
JOIN sij.trucks t ON t.truck_id = tr.truck_id
GROUP BY t.make
UNION ALL
SELECT 'driver terminal',
       d.home_terminal,
       COUNT(*),
       ROUND((SUM(tr.actual_distance_miles) / SUM(tr.fuel_gallons_used))::numeric, 2),
       ROUND((100.0 * SUM(tr.idle_time_hours) / SUM(tr.actual_duration_hours))::numeric, 1)
FROM sij.trips tr
JOIN sij.drivers d ON d.driver_id = tr.driver_id
GROUP BY d.home_terminal
ORDER BY level, idle_pct DESC;

-- Q7b Drivers with the highest idle share (minimum 200 trips)
SELECT d.driver_id,
       d.home_terminal,
       COUNT(*)                                                                        AS trips,
       ROUND((100.0 * SUM(tr.idle_time_hours) / SUM(tr.actual_duration_hours))::numeric, 1) AS idle_pct,
       ROUND(SUM(tr.idle_time_hours)::numeric, 0)                                      AS idle_hours,
       ROUND((SUM(tr.actual_distance_miles) / SUM(tr.fuel_gallons_used))::numeric, 2)  AS mpg
FROM sij.trips tr
JOIN sij.drivers d ON d.driver_id = tr.driver_id
GROUP BY d.driver_id, d.home_terminal
HAVING COUNT(*) >= 200
ORDER BY idle_pct DESC
LIMIT 10;

-- Q8 How do driver productivity and experience affect trips, miles and on-time rate?
SELECT CASE WHEN d.years_experience < 5  THEN '1. 0-4 years'
            WHEN d.years_experience < 10 THEN '2. 5-9 years'
            WHEN d.years_experience < 20 THEN '3. 10-19 years'
            ELSE '4. 20+ years' END                              AS experience_band,
       COUNT(DISTINCT d.driver_id)                               AS drivers,
       ROUND(AVG(m.trips_completed)::numeric, 1)                 AS trips_per_month,
       ROUND(AVG(m.total_miles)::numeric, 0)                     AS miles_per_month,
       ROUND((100.0 * AVG(m.on_time_delivery_rate))::numeric, 1) AS on_time_pct,
       ROUND(AVG(m.average_mpg)::numeric, 2)                     AS avg_mpg
FROM sij.driver_monthly_metrics m
JOIN sij.drivers d ON d.driver_id = m.driver_id
GROUP BY 1
ORDER BY 1;
