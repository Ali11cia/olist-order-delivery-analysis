-- OLIST E-COMMERCE DASHBOARD 

-- Freight is summed across all items per order.
-- Delivery metrics use recorded order-level timestamps.
-- Delays cannot be attributed to individual items or sellers.

-- VIEW 1: -- Summarizes items, prices, and shipping fees into one row per order
CREATE VIEW order_item_totals AS
SELECT order_id,
       COUNT(*) AS item_count,
       SUM(price) AS product_value,
       SUM(freight_value) AS freight_value
FROM order_items
GROUP BY order_id;

-- VIEW 2: Creates a master table combining order milestones, item counts, total financials, and processing metrics
CREATE VIEW analysis_orders AS
SELECT o.*,
       COALESCE(i.item_count, 0) AS item_count,
       i.product_value,
       i.freight_value,
       COALESCE(o.order_status = 'delivered'
           AND o.delivery_date IS NOT NULL
           AND o.days_to_deliver IS NOT NULL
           AND o.order_delivered_customer_date >= o.order_purchase_timestamp,
           FALSE) AS valid_delivery,
       COALESCE(o.order_status = 'delivered'
           AND o.order_approved_at >= o.order_purchase_timestamp
           AND o.order_delivered_carrier_date >= o.order_approved_at
           AND o.order_delivered_customer_date >= o.order_delivered_carrier_date,
           FALSE) AS valid_fulfillment,
       EXTRACT(EPOCH FROM (o.order_approved_at
           - o.order_purchase_timestamp)) / 86400.0 AS approval_days,
       EXTRACT(EPOCH FROM (o.order_delivered_carrier_date
           - o.order_approved_at)) / 86400.0 AS pickup_days,
       EXTRACT(EPOCH FROM (o.order_delivered_customer_date
           - o.order_delivered_carrier_date)) / 86400.0 AS transit_days,
       CASE WHEN i.product_value < 50 THEN 'Below R$50'
            WHEN i.product_value < 150 THEN 'R$50 to below R$150'
            WHEN i.product_value >= 150 THEN 'R$150+'
            ELSE 'No item value' END AS value_band,
       i.freight_value / NULLIF(i.product_value, 0) AS freight_ratio
FROM orders o
LEFT JOIN order_item_totals i USING (order_id)
WHERE o.purchase_date >= DATE '2017-01-01'
  AND o.purchase_date < DATE '2018-09-01';

SELECT order_status, COUNT(order_id) FROM analysis_orders
GROUP BY order_status
ORDER BY COUNT(order_id) DESC; 

-- Q1. Which months experienced both higher-than-average order volume and above-average late-delivery rates?
WITH monthly AS (
    SELECT purchase_month, COUNT(*) AS total_orders,
           COUNT(*) FILTER (WHERE valid_delivery) AS eligible_orders,
           COUNT(*) FILTER (WHERE valid_delivery AND delivery_status = 'Late') AS late_orders
    FROM analysis_orders
    GROUP BY purchase_month
)

SELECT to_char("purchase_month", 'YYYY-MM') AS "Purchase month",
total_orders AS "Total orders", 
eligible_orders AS "Delivered orders", late_orders AS "Late orders",
       ROUND(100.0 * late_orders / NULLIF(eligible_orders, 0), 2) AS "Late rate (%)"
FROM monthly
WHERE total_orders > (SELECT AVG(total_orders) FROM monthly)
  AND late_orders::numeric / NULLIF(eligible_orders, 0) >
      (SELECT SUM(late_orders)::numeric / NULLIF(SUM(eligible_orders), 0)
       FROM monthly)
ORDER BY purchase_month;

-- Q2. Do orders with multiple items take longer to arrive or have a higher late delivery rate than single-item orders? 
SELECT CASE WHEN item_count = 1 THEN 'Single item'
            ELSE 'Multiple items' END AS "Item group",
       COUNT(*) AS "Delivered orders",
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP
             (ORDER BY days_to_deliver)::numeric, 2) AS "Median delivery days",
	   ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP
             (ORDER BY days_to_deliver)::numeric, 2) AS "90th percentile delivery days",
       ROUND(100.0 * AVG(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END), 2)
           AS "Late rate (%)"
FROM analysis_orders
WHERE valid_delivery AND item_count > 0
GROUP BY 1;

-- Q3. How does delivery performance differ by product value?
SELECT value_band AS "Product value band", COUNT(*) AS "Delivered orders",
       COUNT(*) FILTER (WHERE delivery_status = 'Late') AS "Late orders",
       ROUND(100.0 * AVG(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END), 2)
           AS "Late rate (%)",
	   ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP
             (ORDER BY days_to_deliver)::numeric, 2) AS "Median delivery days",
       ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP
             (ORDER BY days_to_deliver)::numeric, 2) AS "90th percentile delivery days"
FROM analysis_orders
WHERE valid_delivery AND item_count > 0
GROUP BY 1
ORDER BY 4 ASC;

-- Q4. Which product value and item-count groups had higher late rates?
SELECT value_band AS "Product value band",
       CASE WHEN item_count = 1 THEN 'Single item'
            ELSE 'Multiple items' END AS "Item group",
       COUNT(*) AS "Delivered orders",
       COUNT(*) FILTER (WHERE delivery_status = 'Late') AS "Late orders",
       ROUND(100.0 * AVG(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END), 2)
           AS "Late rate (%)"
FROM analysis_orders
WHERE valid_delivery AND item_count > 0
GROUP BY 1, 2
ORDER BY 
    CASE value_band
        WHEN 'Below R$50'           THEN 1
        WHEN 'R$50 to below R$150'  THEN 2
        WHEN 'R$150+'               THEN 3
        ELSE 4 
    END ASC,
    2 ASC;

-- Q5. Which fulfillment stages take longer for late deliveries, and does this pattern differ by product value? 
SELECT value_band AS "Product value band",
       CASE WHEN delivery_status = 'Late' THEN 'Late'
            ELSE 'By promised date' END AS "Delivery group",
       COUNT(*) AS "Delivered orders",
       ROUND(AVG(approval_days), 2) AS "Avg approval days",
       ROUND(AVG(pickup_days), 2) AS "Avg pickup days",
       ROUND(AVG(transit_days), 2) AS "Avg transit days"
FROM analysis_orders
WHERE valid_delivery AND valid_fulfillment
  AND delivery_status IN ('Early', 'On Time', 'Late')
GROUP BY value_band, 
         CASE WHEN delivery_status = 'Late' THEN 'Late' ELSE 'By promised date' END
ORDER BY 
    CASE value_band
        WHEN 'Below R$50'           THEN 1
        WHEN 'R$50 to below R$150'  THEN 2
        WHEN 'R$150+'               THEN 3
        ELSE 4 
    END ASC,
    CASE WHEN CASE WHEN delivery_status = 'Late' THEN 'Late' ELSE 'By promised date' END = 'By promised date' THEN 1 
         ELSE 2 
    END ASC;

-- Q6. How does the time from approval to carrier pickup relate to late rates?
SELECT CASE WHEN pickup_days <= 1 THEN 'Up to 1 day'
            WHEN pickup_days <= 3 THEN 'Over 1 to 3 days'
            ELSE 'Over 3 days' END AS "Days to ship",
       value_band AS "Product value band",
       COUNT(*) AS "Delivered orders",
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(PARTITION BY 
           CASE WHEN pickup_days <= 1 THEN 'Up to 1 day'
                WHEN pickup_days <= 3 THEN 'Over 1 to 3 days'
                ELSE 'Over 3 days' END), 2) AS "% of shipping group",
       ROUND(100.0 * AVG(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END), 2)
           AS "Late rate (%)"
FROM analysis_orders
WHERE valid_fulfillment AND valid_delivery
  AND delivery_status IN ('Early', 'On Time', 'Late')
GROUP BY 1, 2
ORDER BY 
    CASE MAX(CASE WHEN pickup_days <= 1 THEN 'Up to 1 day'
                  WHEN pickup_days <= 3 THEN 'Over 1 to 3 days'
                  ELSE 'Over 3 days' END)
        WHEN 'Up to 1 day'       THEN 1
        WHEN 'Over 1 to 3 days'  THEN 2
        WHEN 'Over 3 days'       THEN 3
    END ASC,
    CASE value_band
        WHEN 'Below R$50'           THEN 1
        WHEN 'R$50 to below R$150'  THEN 2
        WHEN 'R$150+'               THEN 3
        ELSE 4 
    END ASC;

-- Q7. Where did freight charges exceed product value?
SELECT value_band AS "Product value band", COUNT(*) AS "Orders with items",
       COUNT(*) FILTER (WHERE freight_value > product_value) AS "High-freight orders",
       ROUND(100.0 * COUNT(*) FILTER (WHERE freight_value > product_value) / NULLIF(COUNT(*), 0), 2) 
	   AS "High-freight rate (%)"
FROM analysis_orders
WHERE item_count > 0 AND product_value > 0 AND valid_delivery
GROUP BY 1
ORDER BY 4 DESC;

-- Q8. How did freight charges relate to delivery time?  
SELECT value_band AS "Product value band",
       CASE WHEN freight_value < 20 THEN 'Below R$20'
            WHEN freight_value < 40 THEN 'R$20 to below R$40'
            ELSE 'R$40+' END AS "Freight value band",
       COUNT(*) AS "Delivered orders",
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP
             (ORDER BY days_to_deliver)::numeric, 2) AS "Median delivery days"
FROM analysis_orders
WHERE valid_delivery 
  AND item_count > 0 AND freight_value IS NOT NULL
GROUP BY 1, 2
ORDER BY 
    CASE value_band
        WHEN 'Below R$50'           THEN 1
        WHEN 'R$50 to below R$150'  THEN 2
        WHEN 'R$150+'               THEN 3
        ELSE 4 
    END ASC,

    CASE CASE WHEN freight_value < 20 THEN 'Below R$20'
              WHEN freight_value < 40 THEN 'R$20 to below R$40'
              ELSE 'R$40+' END
        WHEN 'Below R$20'          THEN 1
        WHEN 'R$20 to below R$40'  THEN 2
        WHEN 'R$40+'               THEN 3
    END ASC;

-- Q9. Which product value band had the highest cancellation rate without recorded delivery, measured against all eligible orders in that band? 
SELECT value_band AS "Product value band", COUNT(*) AS "Orders with items",
       COUNT(*) FILTER (WHERE order_status = 'canceled' 
                          AND order_delivered_customer_date IS NULL) AS "Cancelled orders with no delivery recorded",
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_status = 'canceled' 
                                         AND order_delivered_customer_date IS NULL) 
             / NULLIF(COUNT(*), 0), 2) AS "Cancellation rate (%)"
FROM analysis_orders
WHERE item_count > 0 AND product_value > 0
GROUP BY 1
ORDER BY 4 DESC;

-- Q10. Which recorded fulfillment milestones dominated cancellations?
SELECT CASE WHEN order_delivered_customer_date IS NOT NULL THEN 'Delivery recorded'
            WHEN order_delivered_carrier_date IS NOT NULL THEN 'Carrier pickup recorded'
            WHEN order_approved_at IS NOT NULL THEN 'Approval recorded'
            ELSE 'No approval recorded' END AS "Latest recorded milestone",
       COUNT(*) AS "Canceled orders",
       COUNT(*) FILTER (WHERE item_count = 0) AS "Cancelled without items",
       ROUND(SUM(product_value), 2) AS "Product_value (R$)"
FROM analysis_orders
WHERE order_status = 'canceled'
GROUP BY 1
ORDER BY 4 DESC NULLS LAST;

-- Q11. Which groups should stakeholders prioritise? (above-average freight-to-product ratio or above-average late delivery rate) 
WITH eligible AS (
    SELECT value_band,
           CASE WHEN item_count = 1 THEN 'Single item'
                ELSE 'Multiple items' END AS item_group,
           freight_ratio,
           CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END AS late_orders
    FROM analysis_orders
    WHERE valid_delivery 
      AND item_count > 0 AND product_value > 0 AND freight_ratio IS NOT NULL
)
SELECT value_band AS "Product value band", 
       item_group AS "Item group",
       COUNT(*) AS "Delivered orders",
	   SUM(late_orders) AS "Late orders",
       ROUND(100.0 * AVG(freight_ratio), 2) AS "Average freight ratio (%)",
       ROUND(100.0 * AVG(late_orders), 2) AS "Late rate (%)"
FROM eligible
GROUP BY 1, 2
HAVING AVG(freight_ratio) > (SELECT AVG(freight_ratio) FROM eligible)
   OR AVG(late_orders) > (SELECT AVG(late_orders) FROM eligible)
ORDER BY 
    CASE value_band
        WHEN 'Below R$50'           THEN 1
        WHEN 'R$50 to below R$150'  THEN 2
        WHEN 'R$150+'               THEN 3
        ELSE 4 
    END ASC,
    2 ASC;





