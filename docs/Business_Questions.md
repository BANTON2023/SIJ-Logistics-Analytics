# SIJ Logistics & Analytics — How the Business Questions Were Answered

This document links each of the 16 business questions to the place in the report
that answers it, the measures behind it, and what the answer is.
Figures cover the full period, January 2022 to December 2024, with no filters applied.

**How to read the tables**

- **Where in the report:** the page (sidebar button) and the visual or KPI card to look at.
- **Measures:** the calculations in the `_Measures` table that produce the number.
- **Answer:** the finding in plain language.

---

## The big picture: three themes connect everything

The 16 questions fall into four areas, but the answers keep pointing to three themes.

```
 1. RELIABILITY ─────────► Service ─► Customers ─► Revenue growth
    Late deliveries (45% on time) make it harder to win more of each
    customer's freight (we capture only 16% of their potential).

 2. FUEL ────────────────► Fleet ───► Cost ──────► Profit
    Idling (28% of trip time) burns fuel, and fuel is 92% of tracked cost.

 3. DATA QUALITY ────────► every area
    Missing costs (driver pay, insurance), trips with no truck, and
    "inactive" customers who still book loads limit how far we can trust
    some numbers.
```

- **Theme 1, reliability**, links questions 3, 9, 10, 11 and 2. The planning problem
  behind late deliveries (Q11) is what holds back on-time performance (Q9), wastes time
  at docks (Q10), and weakens the case for winning more freight from customers (Q3).
- **Theme 2, fuel**, links questions 7, 13, 14 and 16. Fuel prices fell (Q16), so cost
  per load fell (Q13), but fuel economy and idling did not improve (Q7). Fuel still
  dominates cost (Q14).
- **Theme 3, data quality**, affects questions 4, 6, 15 and every profit figure.

---

## Customers

| # | Question | Where in the report | Measures | Answer |
| --- | --- | --- | --- | --- |
| 1 | Which customers bring in the most revenue, and how concentrated is it? | **Customers** › *Revenue by Customer*, *Customer Scorecard* | Total Revenue, Customer Revenue Share % | The largest account (XYZ Foods, $1.5M) is only 0.6% of revenue, and the top 10 accounts together are 5.7%. **Revenue is not concentrated**, so the risk of losing one account is low. Note: the 200 accounts share only 107 names (7 accounts are called "First Group"), so the *Revenue by Customer Name* chart combines them; the scorecard shows one row per account (theme 3). |
| 2 | How do revenue per load and volume differ by customer type and freight type? | **Customers** › *Avg Revenue per Load by Freight Type*; **Executive Overview** › *Revenue by Customer Type*; Customer Type slicer | Avg Revenue per Load, Total Loads, Total Revenue | Revenue per load is about **$3,070 for every type**, from Food/Beverage ($3,056) to Automotive ($3,102). Contract customers bring in the most revenue (38%), then spot (32%) and dedicated (31%). |
| 3 | How does revenue compare with customers' annual revenue potential? | **Customers** › *Revenue vs Potential* KPI and scorecard column | Revenue vs Potential % | We earned **16%** of customers' stated potential. 36 customers give us less than 10%. This is the main growth opportunity. |
| 4 | How does revenue trend year over year for active and inactive accounts? | **Customers** › Account Status slicer with the *Total Revenue* KPI; **Executive Overview** › *Revenue vs Operating Cost by Month* | Total Revenue | Active accounts: about $73M a year. Inactive accounts: about $14M a year, **steady in all three years**. Customers marked "inactive" still book loads, so the account status in the data is out of date (theme 3). |

## Fleet

| # | Question | Where in the report | Measures | Answer |
| --- | --- | --- | --- | --- |
| 5 | How do utilization, downtime and miles compare by truck, make and model year? | **Fleet** › *Utilization by Make*, *Truck Scorecard*, Truck Make slicer | Avg Utilization Rate, Downtime Hours, Total Miles | Utilization is **83% for every make** (82.7% to 83.8%). Volvo trucks have the most downtime (18.0 hours per truck per month, against 15.0 for Kenworth). |
| 6 | Which trucks cost the most to maintain, per truck and per mile? | **Fleet** › *Maintenance Cost per Mile by Model Year*, *Truck Scorecard* | Maintenance Cost per Mile, Total Maintenance Cost | 2018 trucks cost the most per mile ($0.073, against $0.032 for 2020 trucks). The single most expensive truck, unit 2335 (Peterbilt, 2018), cost $90k, about twice the median truck ($46k). |
| 7 | How do fuel efficiency (MPG) and idle time compare by truck and by driver? | **Fleet** › *MPG by Home Terminal*, *Avg MPG* and *Idle Time* KPIs | Avg MPG, Idle % | MPG is **6.45 across all makes and terminals**. Idle time is **28% of trip hours**, the clearest fuel saving available (theme 2). |
| 8 | How do driver productivity and experience affect trips, miles and on-time rate? | **Fleet** › *Active Drivers* KPI, Home Terminal slicer | Active Drivers, Miles per Driver | Experience makes **almost no difference**. Drivers with 0–4 years and 20+ years both complete about 19 trips and 26,500–27,000 miles a month, with on-time rates of 44–45%. Late deliveries are a planning issue, not a driver skill issue. *There is no chart for this yet; see "Gaps" below.* |

## Service

| # | Question | Where in the report | Measures | Answer |
| --- | --- | --- | --- | --- |
| 9 | What is the on-time rate by customer, facility, route and month? | **Service** › *On-Time Delivery % by Month*, *Route Service Levels*; **Customers** › scorecard; Facility Type slicer | On-Time % | **55.7% overall**: 66.7% of pickups and 44.6% of deliveries. The rate is flat every month and year, and the same at every facility type (55–56%), so the cause is company-wide (theme 1). |
| 10 | Where does detention (waiting) time build up, by facility and customer? | **Service** › *Avg Detention by Facility (min)*, *Avg Detention* KPI | Avg Detention (min), Total Detention Hours | The average wait is **92 minutes** per stop, and even the worst facilities are only slightly higher (94 minutes). 36% of stops wait more than 2 hours. Waiting is widespread, so the fix is a policy (charging for waiting time), not a few sites. |
| 11 | How do actual trip times compare with planned transit days? | **Service** › *Actual Transit Days* and *Planned Transit Days* KPIs, *Route Service Levels* | Avg Actual Transit Days, Avg Planned Transit Days | Trips take about **1.0 day against 2.1 days planned**. 9,382 stops were marked late because they arrived more than 2 hours **early**. Appointment times are not based on real drive times, and this is the root cause behind Q9 (theme 1). |
| 12 | What are the incident rate, the preventable share and claim costs? | **Service** › *Safety Incidents by Type*, *Incidents / M Miles* and *Preventable Incidents* KPIs | Total Safety Incidents, Incidents per Million Miles, Preventable Incident %, Total Claim Amount | **170 incidents** (1.4 per million miles), 33 with injuries, **$2.65M** in claims. 38% were preventable ($0.9M). DOT violations are the most common (39); equipment damage is the most expensive ($741k). 18 drivers had 3 or more incidents. |

## Cost

| # | Question | Where in the report | Measures | Answer |
| --- | --- | --- | --- | --- |
| 13 | How do operating cost per load and per mile trend over time? | **Cost** › *Cost per Mile by Month*, *Cost per Mile* KPI | Operating Cost per Load, Cost per Mile, Fuel Cost per Mile | Cost per load fell **12%**, from $1,272 (2022) to $1,114 (2024). Cost per mile averages $0.83, of which fuel is $0.78. |
| 14 | How do fuel, maintenance and incident costs compare as shares of total cost? | **Executive Overview** › *Cost Mix by Year* | Total Fuel Cost, Total Maintenance Cost, Total Claim Amount | **Fuel 92%**, maintenance 5.5%, incident claims 2.6%. Fuel is where savings matter (theme 2). |
| 15 | What is the margin by customer and by route? | **Cost** › *Route Margin after Fuel*; **Customers** › scorecard *Margin after Fuel %* | Margin after Fuel, Margin after Fuel % | By customer, margin after fuel is about **64%** overall, and 63–65% for the largest customers. By route it varies widely: long routes such as Charlotte–Portland reach 84%, while short routes such as New York–Philadelphia show fuel costs above revenue. Check these short routes' pricing and fuel records (theme 3). |
| 16 | How has the fuel price per gallon moved, by state and location? | **Cost** › *Fuel Price per Gallon by State*, Fuel State slicer, *Fuel Price / Gallon* KPI | Avg Fuel Price per Gallon | Prices fell from **$4.20 (2022) to $3.85 (2023) and $3.65 (2024)**. Between states they differ by only 2 cents ($3.89 to $3.91), so choosing where to buy fuel saves little. Using less fuel is what counts. |

---

## How the questions were answered (method)

1. **Model:** the data was organised into a star-style model with a shared `Calendar`
   table, so every page can be filtered by year, quarter and month.
2. **Measures:** 47 measures in the `_Measures` table turn the raw records into business
   numbers such as On-Time %, Cost per Mile and Margin after Fuel. The measures added for
   these questions are listed in `TSA_capstone_new_measures.dax`.
3. **Report:** each area has its own page, with six KPI cards for the headline numbers,
   a lead chart for the main trend, and detail charts and tables for the breakdowns.
4. **Checks:** totals were checked against the source CSV files. Some breakdowns, such as
   driver experience (Q8) and lateness in minutes (Q11), were worked out from the source
   files to explain what the report shows.

## Gaps and suggested additions

- **Q8, driver experience:** add a chart of on-time % and miles by years of experience on
  the Fleet page, so the answer can be seen in the report.
- **Q4, account status:** confirm which customers are really inactive before using the
  Account Status slicer for decisions.
- **Profit (Q15 and KPIs marked `*`):** add driver pay, insurance and overheads to the data
  for a true profit figure.
- **Short routes (Q15):** review the fuel records linked to short routes such as New
  York–Philadelphia before drawing pricing conclusions.

See [Executive_Summary.md](Executive_Summary.md) for the recommendations that follow from
these answers.
