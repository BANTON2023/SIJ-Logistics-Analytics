-- =============================================================================
-- Cost: questions 13-16
-- As in the Power BI model, trip-level costs (fuel, incident claims) are dated by
-- the load date (fuel -> trip -> load), and maintenance by its own date.
-- Operating cost = fuel + maintenance; the data has no driver pay or overheads.
-- =============================================================================

-- Q13 How do operating cost per load and per mile trend over time (by year)?
WITH trip_year AS (
    SELECT t.trip_id, t.actual_distance_miles, EXTRACT(YEAR FROM l.load_date)::int AS year
    FROM sij.trips t
    JOIN sij.loads l ON l.load_id = t.load_id
),
fuel AS (
    SELECT ty.year, SUM(f.total_cost) AS fuel_cost, SUM(f.gallons) AS gallons
    FROM sij.fuel_purchases f
    JOIN trip_year ty ON ty.trip_id = f.trip_id
    GROUP BY ty.year
),
maintenance AS (
    SELECT EXTRACT(YEAR FROM maintenance_date)::int AS year, SUM(total_cost) AS maintenance_cost
    FROM sij.maintenance_records
    GROUP BY EXTRACT(YEAR FROM maintenance_date)
),
volume AS (
    SELECT EXTRACT(YEAR FROM l.load_date)::int AS year,
           COUNT(DISTINCT l.load_id)            AS loads,
           SUM(t.actual_distance_miles)         AS miles
    FROM sij.loads l
    JOIN sij.trips t ON t.load_id = l.load_id
    GROUP BY EXTRACT(YEAR FROM l.load_date)
)
SELECT v.year,
       v.loads,
       ROUND((f.fuel_cost + m.maintenance_cost)::numeric, 2)                      AS operating_cost,
       ROUND(((f.fuel_cost + m.maintenance_cost) / v.loads)::numeric, 2)          AS cost_per_load,
       ROUND(((f.fuel_cost + m.maintenance_cost) / v.miles)::numeric, 4)          AS cost_per_mile,
       ROUND((f.fuel_cost / v.miles)::numeric, 4)                                 AS fuel_cost_per_mile,
       ROUND((f.fuel_cost / f.gallons)::numeric, 3)                               AS fuel_price_per_gallon
FROM volume v
JOIN fuel f        ON f.year = v.year
JOIN maintenance m ON m.year = v.year
ORDER BY v.year;

-- Q14 How do fuel, maintenance and incident costs compare as shares of total cost?
WITH costs AS (
    SELECT 'Fuel' AS cost_type, SUM(total_cost) AS amount FROM sij.fuel_purchases
    UNION ALL
    SELECT 'Maintenance', SUM(total_cost) FROM sij.maintenance_records
    UNION ALL
    SELECT 'Incident claims', SUM(claim_amount) FROM sij.safety_incidents
)
SELECT cost_type,
       ROUND(amount::numeric, 2)                                   AS amount,
       ROUND((100.0 * amount / SUM(amount) OVER ())::numeric, 1)   AS share_pct
FROM costs
ORDER BY amount DESC;

-- Q15 What is the margin after fuel by route?
-- Maintenance is recorded per truck, not per load, so it is left out here
-- (as in the Power BI measure "Margin after Fuel"). Lowest margins first.
WITH trip_fuel AS (
    SELECT trip_id, SUM(total_cost) AS fuel_cost
    FROM sij.fuel_purchases
    GROUP BY trip_id
),
route_totals AS (
    SELECT r.origin_city || ' - ' || r.destination_city AS route,
           r.typical_distance_miles                     AS distance_miles,
           COUNT(DISTINCT l.load_id)                    AS loads,
           SUM(l.revenue)                               AS revenue,
           SUM(COALESCE(tf.fuel_cost, 0))               AS fuel_cost
    FROM sij.loads l
    JOIN sij.routes r     ON r.route_id = l.route_id
    JOIN sij.trips t      ON t.load_id = l.load_id
    LEFT JOIN trip_fuel tf ON tf.trip_id = t.trip_id
    GROUP BY r.origin_city, r.destination_city, r.typical_distance_miles
)
SELECT route,
       distance_miles,
       loads,
       ROUND(revenue::numeric, 2)                                     AS revenue,
       ROUND(fuel_cost::numeric, 2)                                   AS fuel_cost,
       ROUND((revenue - fuel_cost)::numeric, 2)                       AS margin_after_fuel,
       ROUND((100.0 * (revenue - fuel_cost) / revenue)::numeric, 1)   AS margin_after_fuel_pct
FROM route_totals
ORDER BY margin_after_fuel_pct
LIMIT 15;

-- Q15b Margin after fuel by customer (lowest first)
WITH trip_fuel AS (
    SELECT trip_id, SUM(total_cost) AS fuel_cost
    FROM sij.fuel_purchases
    GROUP BY trip_id
),
customer_totals AS (
    SELECT c.customer_name,
           c.customer_type,
           SUM(l.revenue)                 AS revenue,
           SUM(COALESCE(tf.fuel_cost, 0)) AS fuel_cost
    FROM sij.loads l
    JOIN sij.customers c   ON c.customer_id = l.customer_id
    JOIN sij.trips t       ON t.load_id = l.load_id
    LEFT JOIN trip_fuel tf ON tf.trip_id = t.trip_id
    GROUP BY c.customer_name, c.customer_type
)
SELECT customer_name,
       customer_type,
       ROUND(revenue::numeric, 2)                                   AS revenue,
       ROUND((revenue - fuel_cost)::numeric, 2)                     AS margin_after_fuel,
       ROUND((100.0 * (revenue - fuel_cost) / revenue)::numeric, 1) AS margin_after_fuel_pct
FROM customer_totals
ORDER BY margin_after_fuel_pct
LIMIT 15;

-- Q16 How has the fuel price per gallon moved, by state? (price = cost / gallons)
SELECT location_state,
       COUNT(*)                                              AS purchases,
       ROUND(SUM(gallons)::numeric, 0)                       AS gallons,
       ROUND((SUM(total_cost) / SUM(gallons))::numeric, 3)   AS price_per_gallon
FROM sij.fuel_purchases
GROUP BY location_state
ORDER BY price_per_gallon DESC;

-- Q16b Fuel price per gallon by year and quarter of purchase
SELECT EXTRACT(YEAR FROM purchase_date)::int                         AS year,
       (EXTRACT(MONTH FROM purchase_date)::int + 2) / 3               AS quarter,
       ROUND((SUM(total_cost) / SUM(gallons))::numeric, 3)           AS price_per_gallon,
       ROUND(SUM(gallons)::numeric, 0)                               AS gallons
FROM sij.fuel_purchases
GROUP BY 1, 2
ORDER BY 1, 2;
