-- =============================================================================
-- Customers: questions 1-4
-- See docs/Business_Questions.md for the answers and where the report shows them.
-- =============================================================================

-- Q1 Which customers bring in the most revenue, and how concentrated is it?
-- Top 20 accounts with their share of revenue and the running (cumulative) share.
-- Grouped by customer_id: 200 accounts share only 107 names (e.g. 7 accounts
-- are called "First Group"), so grouping by name would merge different accounts.
WITH customer_revenue AS (
    SELECT c.customer_id,
           c.customer_name,
           c.customer_type,
           SUM(l.revenue) AS revenue
    FROM sij.loads l
    JOIN sij.customers c ON c.customer_id = l.customer_id
    GROUP BY c.customer_id, c.customer_name, c.customer_type
),
ranked AS (
    SELECT customer_id,
           customer_name,
           customer_type,
           revenue,
           RANK() OVER (ORDER BY revenue DESC)                        AS revenue_rank,
           100.0 * revenue / SUM(revenue) OVER ()                     AS share_pct,
           100.0 * SUM(revenue) OVER (ORDER BY revenue DESC
                                      ROWS UNBOUNDED PRECEDING)
                 / SUM(revenue) OVER ()                               AS cumulative_share_pct
    FROM customer_revenue
)
SELECT revenue_rank,
       customer_id,
       customer_name,
       customer_type,
       ROUND(revenue::numeric, 2)              AS revenue,
       ROUND(share_pct::numeric, 2)            AS share_pct,
       ROUND(cumulative_share_pct::numeric, 2) AS cumulative_share_pct
FROM ranked
WHERE revenue_rank <= 20
ORDER BY revenue_rank;

-- Q2 How do revenue per load and volume differ by customer type and freight type?
SELECT c.customer_type,
       c.primary_freight_type,
       COUNT(*)                                                        AS loads,
       ROUND(SUM(l.revenue)::numeric, 2)                               AS revenue,
       ROUND(AVG(l.revenue)::numeric, 2)                               AS revenue_per_load,
       ROUND((100.0 * SUM(l.revenue) / SUM(SUM(l.revenue)) OVER ())::numeric, 2) AS revenue_share_pct
FROM sij.loads l
JOIN sij.customers c ON c.customer_id = l.customer_id
GROUP BY c.customer_type, c.primary_freight_type
ORDER BY revenue DESC;

-- Q3 How does revenue compare with each customer's annual revenue potential?
-- Revenue is averaged per year (3 years of data) to compare with a yearly potential,
-- matching the Power BI measure "Revenue vs Potential %". Lowest capture first:
-- these are the biggest growth opportunities.
WITH years AS (
    SELECT COUNT(DISTINCT EXTRACT(YEAR FROM load_date)) AS n FROM sij.loads
),
customer_revenue AS (
    SELECT customer_id, SUM(revenue) AS revenue
    FROM sij.loads
    GROUP BY customer_id
)
SELECT c.customer_name,
       c.account_status,
       ROUND(c.annual_revenue_potential::numeric, 0)                          AS annual_potential,
       ROUND((r.revenue / y.n)::numeric, 0)                                   AS avg_annual_revenue,
       ROUND((100.0 * r.revenue / y.n / c.annual_revenue_potential)::numeric, 1) AS capture_pct,
       ROUND((c.annual_revenue_potential - r.revenue / y.n)::numeric, 0)      AS untapped_per_year
FROM sij.customers c
JOIN customer_revenue r ON r.customer_id = c.customer_id
CROSS JOIN years y
WHERE c.annual_revenue_potential > 0
ORDER BY capture_pct
LIMIT 25;

-- Q4 How does revenue trend year over year for active and inactive accounts?
WITH yearly AS (
    SELECT c.account_status,
           EXTRACT(YEAR FROM l.load_date)::int AS year,
           COUNT(DISTINCT l.customer_id)       AS customers,
           SUM(l.revenue)                      AS revenue
    FROM sij.loads l
    JOIN sij.customers c ON c.customer_id = l.customer_id
    GROUP BY c.account_status, EXTRACT(YEAR FROM l.load_date)
)
SELECT account_status,
       year,
       customers,
       ROUND(revenue::numeric, 2) AS revenue,
       ROUND((100.0 * (revenue - LAG(revenue) OVER w) / LAG(revenue) OVER w)::numeric, 2) AS yoy_change_pct
FROM yearly
WINDOW w AS (PARTITION BY account_status ORDER BY year)
ORDER BY account_status, year;
