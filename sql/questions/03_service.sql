-- =============================================================================
-- Service: questions 9-12
-- =============================================================================

-- Q9 What is the on-time rate by event type and facility type?
SELECT e.event_type,
       f.facility_type,
       COUNT(*)                                                                 AS stops,
       ROUND((100.0 * COUNT(*) FILTER (WHERE e.on_time_flag) / COUNT(*))::numeric, 1) AS on_time_pct
FROM sij.delivery_events e
JOIN sij.facilities f ON f.facility_id = e.facility_id
GROUP BY e.event_type, f.facility_type
ORDER BY e.event_type, on_time_pct;

-- Q9b On-time rate by month (the Service page lead chart)
SELECT DATE_TRUNC('month', l.load_date)::date                                   AS month,
       COUNT(*)                                                                 AS stops,
       ROUND((100.0 * COUNT(*) FILTER (WHERE e.on_time_flag) / COUNT(*))::numeric, 1) AS on_time_pct
FROM sij.delivery_events e
JOIN sij.loads l ON l.load_id = e.load_id
GROUP BY DATE_TRUNC('month', l.load_date)
ORDER BY month;

-- Q9c Customers with the lowest delivery on-time rate (minimum 300 deliveries)
SELECT c.customer_name,
       c.customer_type,
       COUNT(*)                                                                 AS deliveries,
       ROUND((100.0 * COUNT(*) FILTER (WHERE e.on_time_flag) / COUNT(*))::numeric, 1) AS on_time_pct
FROM sij.delivery_events e
JOIN sij.loads l     ON l.load_id = e.load_id
JOIN sij.customers c ON c.customer_id = l.customer_id
WHERE e.event_type = 'Delivery'
GROUP BY c.customer_name, c.customer_type
HAVING COUNT(*) >= 300
ORDER BY on_time_pct
LIMIT 10;

-- Q10 Where does detention (waiting) time build up, by facility?
-- "Over 2 h" stops and billable hours assume a 2-hour free allowance per stop.
SELECT f.facility_name,
       f.facility_type,
       COUNT(*)                                                                  AS stops,
       ROUND(AVG(e.detention_minutes)::numeric, 1)                               AS avg_detention_min,
       ROUND((100.0 * COUNT(*) FILTER (WHERE e.detention_minutes > 120) / COUNT(*))::numeric, 1) AS stops_over_2h_pct,
       ROUND((SUM(GREATEST(e.detention_minutes - 120, 0)) / 60.0)::numeric, 0)   AS billable_hours_after_2h
FROM sij.delivery_events e
JOIN sij.facilities f ON f.facility_id = e.facility_id
GROUP BY f.facility_name, f.facility_type
ORDER BY avg_detention_min DESC
LIMIT 15;

-- Q10b Detention revenue opportunity: waiting beyond 2 hours, valued at $75/hour
SELECT COUNT(*)                                                                   AS stops,
       COUNT(*) FILTER (WHERE detention_minutes > 120)                            AS stops_over_2h,
       ROUND((SUM(GREATEST(detention_minutes - 120, 0)) / 60.0)::numeric, 0)      AS billable_hours,
       ROUND((SUM(GREATEST(detention_minutes - 120, 0)) / 60.0 * 75)::numeric, 0) AS value_at_75_per_hour,
       (SELECT ROUND(SUM(accessorial_charges)::numeric, 0) FROM sij.loads)        AS accessorials_billed
FROM sij.delivery_events;

-- Q11 How do actual trip times compare with planned transit days, by route?
-- Also counts stops marked late although they arrived over 2 hours early,
-- a sign that appointments are not set from real drive times.
WITH route_times AS (
    SELECT r.origin_city || ' - ' || r.destination_city AS route,
           r.typical_transit_days                       AS planned_days,
           AVG(t.actual_duration_hours) / 24.0          AS actual_days,
           COUNT(*)                                     AS trips
    FROM sij.trips t
    JOIN sij.loads l  ON l.load_id = t.load_id
    JOIN sij.routes r ON r.route_id = l.route_id
    GROUP BY r.origin_city, r.destination_city, r.typical_transit_days
)
SELECT route,
       trips,
       planned_days,
       ROUND(actual_days::numeric, 2)                  AS actual_days,
       ROUND((actual_days - planned_days)::numeric, 2) AS days_vs_plan
FROM route_times
ORDER BY days_vs_plan
LIMIT 15;

-- Q11b Arrival versus appointment: how late (or early) late stops really were
SELECT event_type,
       COUNT(*) FILTER (WHERE NOT on_time_flag)                                   AS late_stops,
       COUNT(*) FILTER (WHERE NOT on_time_flag
                          AND EXTRACT(EPOCH FROM (actual_datetime - scheduled_datetime)) < -7200) AS flagged_late_but_over_2h_early,
       ROUND((AVG(EXTRACT(EPOCH FROM (actual_datetime - scheduled_datetime)) / 60.0)
              FILTER (WHERE NOT on_time_flag
                        AND EXTRACT(EPOCH FROM (actual_datetime - scheduled_datetime)) > 0))::numeric, 0) AS avg_minutes_late
FROM sij.delivery_events
GROUP BY event_type;

-- Q12 Incident rate, preventable share and claim cost by incident type
SELECT incident_type,
       COUNT(*)                                                                    AS incidents,
       COUNT(*) FILTER (WHERE injury_flag)                                         AS injuries,
       ROUND((100.0 * COUNT(*) FILTER (WHERE preventable_flag) / COUNT(*))::numeric, 1) AS preventable_pct,
       ROUND(SUM(claim_amount)::numeric, 2)                                        AS claims,
       ROUND((SUM(claim_amount) FILTER (WHERE preventable_flag))::numeric, 2)      AS preventable_claims
FROM sij.safety_incidents
GROUP BY incident_type
ORDER BY claims DESC;

-- Q12b Drivers with three or more incidents (coaching list)
SELECT i.driver_id,
       d.home_terminal,
       d.years_experience,
       COUNT(*)                                       AS incidents,
       COUNT(*) FILTER (WHERE i.preventable_flag)     AS preventable,
       ROUND(SUM(i.claim_amount)::numeric, 2)         AS claims
FROM sij.safety_incidents i
JOIN sij.drivers d ON d.driver_id = i.driver_id
GROUP BY i.driver_id, d.home_terminal, d.years_experience
HAVING COUNT(*) >= 3
ORDER BY incidents DESC, claims DESC;
