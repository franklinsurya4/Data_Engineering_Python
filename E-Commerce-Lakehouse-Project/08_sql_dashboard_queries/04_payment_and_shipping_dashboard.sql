
-- ============================================================
-- E-COMMERCE LAKEHOUSE
-- FOLDER 08: SQL DASHBOARD QUERIES
-- FILE 04: PAYMENT AND SHIPPING DASHBOARD
-- ============================================================


-- ============================================================
-- SECTION A: PAYMENT ANALYTICS
-- ============================================================

-- 1. OVERALL PAYMENT PERFORMANCE

SELECT
    payment_date,
    total_payment_transactions,
    successful_transactions,
    failed_transactions,
    pending_transactions,
    refunded_transactions,
    successful_payment_amount,
    refunded_payment_amount,
    failed_payment_amount,
    pending_payment_amount,
    net_payment_amount,
    payment_success_rate,
    payment_failure_rate,
    refund_transaction_rate
FROM workspace.ecommerce_gold.gold_payment_metrics
ORDER BY payment_date;


-- 2. PAYMENT STATUS DISTRIBUTION

SELECT
    payment_status,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(amount) AS total_payment_amount
FROM workspace.ecommerce_silver.silver_payments
GROUP BY payment_status
ORDER BY total_transactions DESC;


-- 3. PAYMENT SUCCESS RATE

SELECT
    payment_method,
    COUNT(*) AS total_transactions,
    SUM(CASE
        WHEN LOWER(TRIM(payment_status)) IN ('success', 'successful')
        THEN 1 ELSE 0
    END) AS successful_transactions,
    ROUND(
        SUM(CASE
            WHEN LOWER(TRIM(payment_status)) IN ('success', 'successful')
            THEN 1.0 ELSE 0.0
        END) * 100.0 / NULLIF(COUNT(*), 0),
        2
    ) AS success_rate_percentage
FROM workspace.ecommerce_silver.silver_payments
GROUP BY payment_method
ORDER BY success_rate_percentage DESC;


-- 4. PAYMENT METHOD PERFORMANCE

SELECT
    payment_method,
    total_transactions,
    successful_transactions,
    failed_transactions,
    pending_transactions,
    refunded_transactions,
    successful_payment_amount,
    refunded_payment_amount,
    net_payment_amount,
    success_rate,
    failure_rate
FROM workspace.ecommerce_gold.gold_payment_method_performance
ORDER BY successful_payment_amount DESC;


-- 5. PAYMENT METHOD SUCCESS RATE

SELECT
    payment_method,
    total_transactions,
    successful_transactions,
    failed_transactions,

    ROUND(
        success_rate,
        2
    ) AS payment_success_rate

FROM workspace.ecommerce_gold.gold_payment_method_performance
ORDER BY payment_success_rate DESC;


-- 6. SUCCESSFUL PAYMENT COLLECTIONS

SELECT
    payment_method,
    COUNT(*) AS successful_transactions,
    COUNT(DISTINCT order_id) AS successful_orders,
    SUM(amount) AS total_successful_collection
FROM workspace.ecommerce_silver.silver_payments
WHERE LOWER(TRIM(payment_status)) IN ('success', 'successful')
GROUP BY payment_method
ORDER BY total_successful_collection DESC;


-- 7. REFUND ANALYSIS

SELECT
    payment_method,
    COUNT(*) AS refunded_transactions,
    COUNT(DISTINCT order_id) AS refunded_orders,
    SUM(amount) AS total_refunded_amount
FROM workspace.ecommerce_silver.silver_payments
WHERE LOWER(TRIM(payment_status)) IN ('refund', 'refunded')
GROUP BY payment_method
ORDER BY total_refunded_amount DESC;


-- 8. PAYMENT METHOD REVENUE CONTRIBUTION

WITH method_revenue AS (

    SELECT
        payment_method,
        successful_payment_amount AS collected_amount
    FROM workspace.ecommerce_gold.gold_payment_method_performance
)

SELECT
    payment_method,
    collected_amount,

    ROUND(
        collected_amount * 100.0 /
        NULLIF(SUM(collected_amount) OVER (), 0),
        2
    ) AS collection_contribution_percentage

FROM method_revenue
ORDER BY collected_amount DESC;


-- 9. MULTIPLE SUCCESSFUL PAYMENTS PER ORDER

SELECT
    order_id,
    COUNT(*) AS successful_payment_count,
    SUM(amount) AS total_successful_payment_amount
FROM workspace.ecommerce_silver.silver_payments
WHERE LOWER(TRIM(payment_status)) IN ('success', 'successful')
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY successful_payment_count DESC;


-- 10. ORDERS WITHOUT PAYMENT ATTEMPTS

SELECT
    o.order_id,
    o.customer_id,
    o.order_timestamp,
    o.order_status,
    o.order_total,
    o.currency
FROM workspace.ecommerce_silver.silver_orders o
LEFT JOIN workspace.ecommerce_silver.silver_payments p
    ON o.order_id = p.order_id
WHERE p.order_id IS NULL
ORDER BY o.order_timestamp DESC;


-- 11. ORDER PAYMENT RECONCILIATION SUMMARY

WITH payment_summary AS (
    SELECT
        order_id,
        SUM(
            CASE
                WHEN LOWER(TRIM(payment_status)) IN ('success', 'successful')
                THEN amount ELSE 0
            END
        ) AS successful_payment_amount,
        SUM(
            CASE
                WHEN LOWER(TRIM(payment_status)) IN ('refund', 'refunded')
                THEN amount ELSE 0
            END
        ) AS refunded_payment_amount
    FROM workspace.ecommerce_silver.silver_payments
    GROUP BY order_id
),

reconciliation AS (
    SELECT
        o.order_id,
        o.order_total,
        COALESCE(p.successful_payment_amount, 0) AS successful_payment_amount,
        COALESCE(p.refunded_payment_amount, 0) AS refunded_payment_amount,
        COALESCE(p.successful_payment_amount, 0)
            - COALESCE(p.refunded_payment_amount, 0) AS net_collected_amount
    FROM workspace.ecommerce_silver.silver_orders o
    LEFT JOIN payment_summary p
        ON o.order_id = p.order_id
)

SELECT
    COUNT(*) AS total_orders,
    SUM(CASE
        WHEN net_collected_amount = order_total THEN 1 ELSE 0
    END) AS fully_reconciled_orders,
    SUM(CASE
        WHEN net_collected_amount < order_total THEN 1 ELSE 0
    END) AS underpaid_orders,
    SUM(CASE
        WHEN net_collected_amount > order_total THEN 1 ELSE 0
    END) AS overpaid_orders,
    SUM(order_total) AS total_order_value,
    SUM(net_collected_amount) AS total_net_collected_amount
FROM reconciliation;


-- 12. PAYMENT AMOUNT VS ORDER VALUE

-- 12. ORDER PAYMENT AMOUNT VS ORDER VALUE

WITH payment_summary AS (
    SELECT
        order_id,
        SUM(
            CASE
                WHEN LOWER(TRIM(payment_status)) IN ('success', 'successful')
                THEN amount ELSE 0
            END
        ) AS successful_payment_amount,
        SUM(
            CASE
                WHEN LOWER(TRIM(payment_status)) IN ('refund', 'refunded')
                THEN amount ELSE 0
            END
        ) AS refunded_payment_amount
    FROM workspace.ecommerce_silver.silver_payments
    GROUP BY order_id
)

SELECT
    o.order_id,
    o.currency,
    o.order_total,
    COALESCE(p.successful_payment_amount, 0) AS successful_payment_amount,
    COALESCE(p.refunded_payment_amount, 0) AS refunded_payment_amount,
    COALESCE(p.successful_payment_amount, 0)
        - COALESCE(p.refunded_payment_amount, 0) AS net_collected_amount,
    o.order_total - (
        COALESCE(p.successful_payment_amount, 0)
        - COALESCE(p.refunded_payment_amount, 0)
    ) AS payment_difference,
    CASE
        WHEN COALESCE(p.successful_payment_amount, 0)
             - COALESCE(p.refunded_payment_amount, 0) = o.order_total
            THEN 'RECONCILED'
        WHEN COALESCE(p.successful_payment_amount, 0)
             - COALESCE(p.refunded_payment_amount, 0) < o.order_total
            THEN 'UNDERPAID'
        ELSE 'OVERPAID'
    END AS reconciliation_status
FROM workspace.ecommerce_silver.silver_orders o
LEFT JOIN payment_summary p
    ON o.order_id = p.order_id
ORDER BY ABS(payment_difference) DESC;


-- ============================================================
-- SECTION B: SHIPPING ANALYTICS
-- ============================================================


-- 13. OVERALL SHIPPING PERFORMANCE

SELECT *
FROM workspace.ecommerce_gold.gold_shipping_metrics;


-- 14. SHIPMENT STATUS DISTRIBUTION

SELECT
    shipment_status,
    COUNT(*) AS total_shipments
FROM workspace.ecommerce_silver.silver_shipments
GROUP BY shipment_status
ORDER BY total_shipments DESC;


-- 15. CARRIER SHIPMENT VOLUME

SELECT
    carrier,
    COUNT(*) AS total_shipments
FROM workspace.ecommerce_silver.silver_shipments
GROUP BY carrier
ORDER BY total_shipments DESC;


-- 16. DELIVERED SHIPMENT COUNT BY CARRIER

SELECT
    carrier,
    COUNT(*) AS delivered_shipments
FROM workspace.ecommerce_silver.silver_shipments
WHERE LOWER(TRIM(shipment_status)) = 'delivered'
GROUP BY carrier
ORDER BY delivered_shipments DESC;


-- 17. AVERAGE DELIVERY TIME BY CARRIER

SELECT
    carrier,
    COUNT(*) AS delivered_shipments,
    ROUND(
        AVG(
            (UNIX_TIMESTAMP(delivered_date) -
             UNIX_TIMESTAMP(shipped_date)) / 3600.0
        ), 2
    ) AS average_delivery_hours,
    ROUND(
        AVG(
            (UNIX_TIMESTAMP(delivered_date) -
             UNIX_TIMESTAMP(shipped_date)) / 86400.0
        ), 2
    ) AS average_delivery_days
FROM workspace.ecommerce_silver.silver_shipments
WHERE LOWER(TRIM(shipment_status)) = 'delivered'
  AND shipped_date IS NOT NULL
  AND delivered_date IS NOT NULL
  AND delivered_date >= shipped_date
GROUP BY carrier
ORDER BY average_delivery_days ASC;


-- 18. DELIVERED SHIPMENT RATE BY CARRIER

SELECT
    carrier,
    COUNT(*) AS total_shipments,
    SUM(CASE
        WHEN LOWER(TRIM(shipment_status)) = 'delivered'
        THEN 1 ELSE 0
    END) AS delivered_shipments,
    ROUND(
        SUM(CASE
            WHEN LOWER(TRIM(shipment_status)) = 'delivered'
            THEN 1.0 ELSE 0.0
        END) * 100.0 / NULLIF(COUNT(*), 0),
        2
    ) AS delivery_rate_percentage
FROM workspace.ecommerce_silver.silver_shipments
GROUP BY carrier
ORDER BY delivery_rate_percentage DESC;


-- 19. SHIPMENTS TAKING MORE THAN SEVEN DAYS

SELECT
    shipment_id,
    order_id,
    carrier,
    shipment_status,
    shipped_date,
    delivered_date,
    ROUND(
        (UNIX_TIMESTAMP(COALESCE(delivered_date, CURRENT_TIMESTAMP()))
         - UNIX_TIMESTAMP(shipped_date)) / 86400.0,
        2
    ) AS shipment_duration_days
FROM workspace.ecommerce_silver.silver_shipments
WHERE shipped_date IS NOT NULL
  AND UNIX_TIMESTAMP(COALESCE(delivered_date, CURRENT_TIMESTAMP()))
      - UNIX_TIMESTAMP(shipped_date) > 7 * 86400
ORDER BY shipment_duration_days DESC;


-- 20. SHIPMENTS NOT YET DELIVERED

SELECT
    shipment_id,
    order_id,
    carrier,
    shipment_status,
    shipped_date,
    tracking_number
FROM workspace.ecommerce_silver.silver_shipments
WHERE LOWER(TRIM(shipment_status)) <> 'delivered'
   OR shipment_status IS NULL
ORDER BY shipped_date DESC;


-- 21. MONTHLY DELIVERY PERFORMANCE

SELECT
    DATE_TRUNC('MONTH', delivered_date) AS delivery_month,
    carrier,
    COUNT(*) AS delivered_shipments,
    ROUND(
        AVG(
            (UNIX_TIMESTAMP(delivered_date) -
             UNIX_TIMESTAMP(shipped_date)) / 86400.0
        ), 2
    ) AS average_delivery_days
FROM workspace.ecommerce_silver.silver_shipments
WHERE LOWER(TRIM(shipment_status)) = 'delivered'
  AND shipped_date IS NOT NULL
  AND delivered_date IS NOT NULL
  AND delivered_date >= shipped_date
GROUP BY DATE_TRUNC('MONTH', delivered_date), carrier
ORDER BY delivery_month, carrier;


-- 22. DELIVERY TIME DISTRIBUTION

WITH delivery_duration AS (
    SELECT
        shipment_id,
        carrier,
        (UNIX_TIMESTAMP(delivered_date) -
         UNIX_TIMESTAMP(shipped_date)) / 86400.0 AS delivery_days
    FROM workspace.ecommerce_silver.silver_shipments
    WHERE LOWER(TRIM(shipment_status)) = 'delivered'
      AND shipped_date IS NOT NULL
      AND delivered_date IS NOT NULL
      AND delivered_date >= shipped_date
)

SELECT
    CASE
        WHEN delivery_days <= 1 THEN '0-1 Days'
        WHEN delivery_days <= 3 THEN '1-3 Days'
        WHEN delivery_days <= 5 THEN '3-5 Days'
        WHEN delivery_days <= 7 THEN '5-7 Days'
        ELSE 'Above 7 Days'
    END AS delivery_time_bucket,
    COUNT(*) AS total_shipments
FROM delivery_duration
GROUP BY
    CASE
        WHEN delivery_days <= 1 THEN '0-1 Days'
        WHEN delivery_days <= 3 THEN '1-3 Days'
        WHEN delivery_days <= 5 THEN '3-5 Days'
        WHEN delivery_days <= 7 THEN '5-7 Days'
        ELSE 'Above 7 Days'
    END
ORDER BY total_shipments DESC;


-- 23. CARRIER PERFORMANCE RANKING

WITH carrier_performance AS (
    SELECT
        carrier,
        COUNT(*) AS delivered_shipments,
        AVG(
            (UNIX_TIMESTAMP(delivered_date) -
             UNIX_TIMESTAMP(shipped_date)) / 86400.0
        ) AS average_delivery_days
    FROM workspace.ecommerce_silver.silver_shipments
    WHERE LOWER(TRIM(shipment_status)) = 'delivered'
      AND shipped_date IS NOT NULL
      AND delivered_date IS NOT NULL
      AND delivered_date >= shipped_date
    GROUP BY carrier
)

SELECT
    carrier,
    delivered_shipments,
    ROUND(average_delivery_days, 2) AS average_delivery_days,
    RANK() OVER (
        ORDER BY average_delivery_days ASC
    ) AS carrier_performance_rank
FROM carrier_performance
ORDER BY carrier_performance_rank;


-- 24. ORDERS WITHOUT SHIPMENT RECORDS

SELECT
    o.order_id,
    o.customer_id,
    o.order_timestamp,
    o.order_status,
    o.order_total,
    o.currency
FROM workspace.ecommerce_silver.silver_orders o
LEFT JOIN workspace.ecommerce_silver.silver_shipments s
    ON o.order_id = s.order_id
WHERE s.order_id IS NULL
ORDER BY o.order_timestamp DESC;


-- ============================================================
-- END OF PAYMENT AND SHIPPING DASHBOARD
-- ============================================================
