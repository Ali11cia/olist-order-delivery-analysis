<div align="center">

# 🛒 Olist Order and Delivery Performance Analysis

### Delivery Performance · Shipping Affordability · Cancellations

**Python → PostgreSQL → Power BI**

*Using order data to identify business priorities.*

</div>

---

## 📌 Project overview

This project analyses order trends, delivery performance, fulfillment times, shipping charges, and cancellations in Olist's Brazilian e-commerce data. It combines data preparation using Python, SQL analysis, and an interactive Power BI dashboard to identify operational patterns and order groups that require attention.

The objective is to move beyond overall averages and help stakeholders decide **where to investigate delays, review shipping affordability, and address cancellations**.

## 🎯 Business focus

- **Order trends:** Which months have higher order volumes?
- **Delivery performance:** Which months and order groups have higher late delivery rates?
- **Fulfillment efficiency:** Which stages take longer for late deliveries?
- **Shipping affordability:** Which order groups face high freight charges relative to product value?
- **Cancellations:** Which order groups have higher cancellation rates and which recorded fulfillment milestones account for the most canceled product value?

## 📊 Data and scope

| Detail | Scope |
|---|---|
| **Source** | [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) |
| **Tables used** | `orders` and `order_items` |
| **Analysis period** | Orders purchased from January 2017 to August 2018 |
| **Orders analysed** | **99,092** |
| **Currency** | Brazilian reais (**R$**) |

The orders table provides statuses and fulfillment timestamps. The order_items table provides item counts, product prices, and freight charges.

Overall order counts include orders without item records. Delivery and financial analyses use the relevant eligibility rules so missing information does not distort comparisons.

## 🛠️ Project approach

| Stage | Contribution |
|---|---|
| **Python — Prepare & Explore** | Checked duplicates, missing dates, and timestamp inconsistencies; created delivery features and explored data distributions. |
| **PostgreSQL — Analyze & Investigate** | Created two reusable views and 11 business questions covering delivery, fulfillment, freight, and cancellations. |
| **Power BI — Visualize & Communicate** | Built an interactive dashboard showing trends, key metrics, and operational differences. |

Item records were summarised into one row per order before joining the tables, preventing repeated order counts. Fulfillment-stage comparisons use complete timestamps in the correct sequence.

## 💡 Key findings

| Finding | Business meaning |
|---|---|
| **March 2018 had an 18.96% late delivery rate** among eligible delivered orders purchased that month. | Monthly comparisons reveal delivery problems hidden by the overall rate. |
| **Single-item orders worth R$150+ had an 8.23% late rate**, compared with 5.02% for multiple-item orders in the same band. | High-value single-item orders are a priority for delivery investigation. |
| **Late orders spent around 27-29 days in transit**, compared with 7-8 days for deliveries by the promised date.* | Transit is a key area to investigate alongside pickup delays. |
| **Multiple-item orders below R$50 had an average freight-to-product ratio of 89.95%.** | Shipping charges can represent a substantial burden relative to product value. |
| **About 92.5% of recorded canceled product value** came from orders with approval recorded but no carrier pickup or delivery recorded. | This group offers a focused starting point for cancellation reviews. |

*The transit comparison uses eligible delivered orders with complete, chronological fulfillment timestamps.*

## 🚀 Business recommendations

- **Optimize peak periods:** Anticipate demand spikes to pilot extra seller dispatch and carrier capacity for late-prone order groups.
- **Monitor carrier handoffs delays:** Pilot a daily review of approved orders still awaiting carrier pickup after three days.
- **Investigate priority groups:** Review high-value single-item orders for the highest late rate, and single-item R$50–R$150 orders for the largest late-order count (**2,764**).
- **Review shipping affordability:** Explore combined shipping or same-seller bundles for low-value orders where feasible.
- **Investigate cancellations:** Collect cancellation reasons and review stock readiness for approved orders without recorded pickup.

Measure carrier-handoff times, late rates, freight burden, and cancellation rates to assess these pilots. These recommendations are proposed actions; no improvement outcomes are claimed.

## 🔎 Limitations

- **Patterns do not prove causes.** The results cannot confirm that higher prices, item counts, or freight charges cause delivery delays.
- **Only two tables are used.** Carrier identity, customer location, product weight and dimensions, and cancellation reasons are outside this analysis.
- **Missing records affect coverage.** Some orders have missing timestamps or item records, so eligible populations differ by question.
- **Recorded milestones are not cancellation times.** They show the latest timestamp available, not when or why an order was canceled.
- **Financial measures are descriptive.** Recorded order value includes freight; canceled product value is not confirmed revenue loss. Average freight ratio is the average of individual order ratios.
- **The data is historical.** Findings support investigation and pilot design, rather than live operational decisions or proven intervention effects.

---

<div align="center">

### 🧠 Skills demonstrated

**Data Cleaning · Exploratory Analysis · SQL · Power BI · Business Interpretation**

*Turning data into clear insights and practical business recommendations.*

</div>
