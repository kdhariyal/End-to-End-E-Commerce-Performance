-- A1. O2C & Communication Performance
-- 1. Compute the O2C connect rate for WhatsApp messages (Clicked + Replied) ÷ Delivered.
SELECT
    ROUND((CAST(SUM(CASE WHEN customer_action IN ('Clicked', 'Replied') THEN 1 ELSE 0 END) AS FLOAT) 
    / NULLIF(SUM(CASE WHEN delivery_status = 'Delivered' THEN 1 ELSE 0 END), 0)) * 100, 2) AS o2c_connect_rate
FROM
	workspace.supertails.communication_logs
WHERE
	channel = 'WhatsApp'
    AND template_type = 'O2C';
  
-- O2C connect rate for WhatsApp messages is: 57.33%


-- 2. Identify the top 5 cities with lowest O2C connect rate.
SELECT
    o.city,
    ROUND(CAST(SUM(CASE WHEN cl.customer_action IN ('Clicked', 'Replied') THEN 1 ELSE 0 END) AS FLOAT) 
    / NULLIF(SUM(CASE WHEN cl.delivery_status = 'Delivered' THEN 1 ELSE 0 END), 0) * 100, 2) AS o2c_connect_rate
FROM
	workspace.supertails.orders o
JOIN
	workspace.supertails.communication_logs cl
ON
	o.order_id = cl.order_id
WHERE
	cl.template_type = 'O2C'
GROUP BY
	o.city
ORDER BY
	o2c_connect_rate
LIMIT 5;

-- Top 5 cities with lowest O2C connect rate are: Delhi, Kolkata, Hyderabad, Bangalore and Mumbai respectively.


-- A2. Customer Purchase Behavior
-- 1. Compute repeat purchase rate by city and product_category
SELECT 
    city,
    product_category,
    COUNT(order_id) AS total_orders,
    ROUND(CAST(SUM(CASE WHEN is_repeat_customer = 'TRUE' THEN 1 ELSE 0 END) AS FLOAT)
    / COUNT(order_id) * 100, 2) AS repeat_purchase_rate
FROM 
    workspace.supertails.orders
GROUP BY 
    city, 
    product_category
ORDER BY 
    city,
    product_category;
    

-- 2. Build a cohort table for first-purchase month × repeat-purchase month.
WITH customer_cohorts AS(
    SELECT
        customer_id,
        DATE_FORMAT(MIN(order_date), 'yyyy-MM') as cohort_month
    FROM
        workspace.supertails.orders
    GROUP BY
        customer_id
),
cohort_orders AS(
    SELECT
        o.customer_id,
        cc.cohort_month,
        TIMESTAMPDIFF(MONTH, cc.cohort_month, o.order_date) AS month_number
    FROM
        workspace.supertails.orders o
    JOIN
        customer_cohorts cc
    ON
        o.customer_id = cc.customer_id
)
SELECT
    cohort_month,
    COUNT(DISTINCT CASE WHEN month_number = 0 THEN customer_id END) AS month_0,
    COUNT(DISTINCT CASE WHEN month_number = 1 THEN customer_id END) AS month_1,
    COUNT(DISTINCT CASE WHEN month_number = 2 THEN customer_id END) AS month_2,
    COUNT(DISTINCT CASE WHEN month_number = 3 THEN customer_id END) AS month_3,
    COUNT(DISTINCT CASE WHEN month_number = 4 THEN customer_id END) AS month_4,
    COUNT(DISTINCT CASE WHEN month_number = 5 THEN customer_id END) AS month_5,
    COUNT(DISTINCT CASE WHEN month_number = 6 THEN customer_id END) AS month_6,
    COUNT(DISTINCT CASE WHEN month_number = 7 THEN customer_id END) AS month_7,
    COUNT(DISTINCT CASE WHEN month_number = 8 THEN customer_id END) AS month_8,
    COUNT(DISTINCT CASE WHEN month_number = 9 THEN customer_id END) AS month_9,
    COUNT(DISTINCT CASE WHEN month_number = 10 THEN customer_id END) AS month_10,
    COUNT(DISTINCT CASE WHEN month_number = 11 THEN customer_id END) AS month_11
FROM
    cohort_orders
GROUP BY
    cohort_month
ORDER BY
    cohort_month;


-- A3. Delivery & Supply Chain
-- 1. Calculate promised vs actual delivery gap in days for each order.
SELECT
    order_id,
    DATE_FORMAT(promised_delivery_date, 'yyyy-mm-dd') AS promised_delivery_date,
    DATE_FORMAT(actual_delivery_date, 'yyyy-mm-dd') AS actual_delivery_date,
    DATE_DIFF(DAY, promised_delivery_date, actual_delivery_date) AS days_gap
FROM
    workspace.supertails.orders;

-- 2. Identify orders delayed due to courier_delay_flag = TRUE.
SELECT
    o.order_id,
    DATE_FORMAT(o.promised_delivery_date, 'yyyy-mm-dd') AS promised_delivery_date,
    DATE_FORMAT(o.actual_delivery_date, 'yyyy-mm-dd') AS actual_delivery_date,
    DATE_DIFF(DAY, o.promised_delivery_date, o.actual_delivery_date) AS days_gap
FROM
    workspace.supertails.orders o
JOIN
    workspace.supertails.supply_chain sc
ON
    o.order_id = sc.order_id
WHERE
    sc.courier_delay_flag = TRUE
    AND DATE_DIFF(DAY, o.promised_delivery_date, o.actual_delivery_date) > 0;

-- 3. Rank courier partners by average shipment_tat_hours.
SELECT
    RANK() OVER (ORDER BY AVG(sc.shipment_tat_hours)) AS courier_partner_rank,
    o.shipment_partner,
    ROUND(AVG(sc.shipment_tat_hours),2) AS avg_shipment_tat_hours
FROM
    workspace.supertails.supply_chain sc
JOIN
    workspace.supertails.orders o
ON
    sc.order_id = o.order_id
GROUP BY
    shipment_partner
ORDER BY
    courier_partner_rank;


-- A4. Communication Channel Insights
-- For each channel (WhatsApp/SMS/Email/Call), calculate:
    -- Delivery rate
    -- Read rate
    -- Click-through rate
    -- Reply rate
SELECT
    channel,
    COUNT(*) AS total_sent,
    ROUND(SUM(CASE WHEN delivery_status IN ('Delivered', 'Read') THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS delivery_rate,
    ROUND(SUM(CASE WHEN delivery_status = 'Read' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS read_rate,
    ROUND(SUM(CASE WHEN customer_action = 'Clicked' THEN 1 ELSE 0 END) / COUNT(*) * 100 ,2) AS click_through_rate,
    ROUND(SUM(CASE WHEN customer_action = 'Replied' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS reply_rate
FROM
    workspace.supertails.communication_logs
GROUP BY
    channel;


-- A5. Support Ticket Analysis. For each issue_category:
    -- Average resolution time (in hours)
    -- Escalation rate
    -- Average CSAT score
    -- Volume of tickets
SELECT
    issue_category,
    COUNT(*) AS volume_of_tickets,
    ROUND(AVG((UNIX_TIMESTAMP(resolved_at) - UNIX_TIMESTAMP(created_at)) / 3600), 2) AS avg_resolution_time_hours,
    ROUND(SUM(CASE WHEN resolution_status = 'Escalated' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS avg_escalation_rate,
    ROUND(AVG(csat_score), 2) AS avg_csat_score
FROM
    workspace.supertails.support_tickets
GROUP BY
    issue_category;


-- A6. Vet Transfer Analysis
-- 1. % of orders where a vet consultation happened within 72 hours of delivery.
WITH vet_consultation AS(
    SELECT
        vc.order_id,
        (UNIX_TIMESTAMP(o.actual_delivery_date) - UNIX_TIMESTAMP(vc.call_start_time)) / 3600 AS vet_consultation_within_hours
    FROM
        workspace.supertails.vet_calls vc
    JOIN
        workspace.supertails.orders o
    ON
        vc.order_id = o.order_id
    WHERE
        vet_transfer_success = TRUE
)
SELECT
    ROUND(SUM(CASE WHEN vet_consultation_within_hours <= 72 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS pct_orders_with_vet_consultation_within_72_hours
FROM
    vet_consultation
-- Ans. There were 50.21% of orders where a vet consultation happened within 72 hours of delivery.

-- 2. Average duration (in minutes) of successful vet transfers.
SELECT
    ROUND(AVG(call_duration_secs / 60), 2) as avg_duration_minutes
FROM
    workspace.supertails.vet_calls
WHERE
    vet_transfer_success = TRUE;
-- Ans. The average duration of successful vet transfers was 15.51 minutes 
