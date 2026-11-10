
-- ============================================================
-- E-COMMERCE LAKEHOUSE
-- FOLDER 08: SQL DASHBOARD QUERIES
-- FILE 06: DASHBOARD VALIDATION AND FINAL QUERIES
-- ============================================================


-- ============================================================
-- SECTION A: SOURCE AND GOLD VALIDATION
-- ============================================================


-- 1. SILVER TABLE ROW COUNTS

SELECT 'silver_customers' AS table_name, COUNT(*) AS total_records
FROM workspace.ecommerce_silver.silver_customers

UNION ALL

SELECT 'silver_products', COUNT(*)
FROM workspace.ecommerce_silver.silver_products

UNION ALL

SELECT 'silver_orders', COUNT(*)
FROM workspace.ecommerce_silver.silver_orders

UNION ALL

SELECT 'silver_order_items', COUNT(*)
FROM workspace.ecommerce_silver.silver_order_items

UNION ALL

SELECT 'silver_payments', COUNT(*)
FROM workspace.ecommerce_silver.silver_payments

UNION ALL

SELECT 'silver_shipments', COUNT(*)
FROM workspace.ecommerce_silver.silver_shipments

UNION ALL

SELECT 'silver_inventory', COUNT(*)
FROM workspace.ecommerce_silver.silver_inventory;


-- 2. GOLD TABLE ROW COUNTS

SELECT 'gold_daily_sales' AS table_name, COUNT(*) AS total_records
FROM workspace.ecommerce_gold.gold_daily_sales

UNION ALL

SELECT 'gold_product_performance', COUNT(*)
FROM workspace.ecommerce_gold.gold_product_performance

UNION ALL

SELECT 'gold_customer_lifetime_value', COUNT(*)
FROM workspace.ecommerce_gold.gold_customer_lifetime_value

UNION ALL

SELECT 'gold_payment_metrics', COUNT(*)
FROM workspace.ecommerce_gold.gold_payment_metrics

UNION ALL

SELECT 'gold_shipping_metrics', COUNT(*)
FROM workspace.ecommerce_gold.gold_shipping_metrics

UNION ALL

SELECT 'gold_inventory_status', COUNT(*)
FROM workspace.ecommerce_gold.gold_inventory_status

UNION ALL

SELECT 'gold_executive_kpis', COUNT(*)
FROM workspace.ecommerce_gold.gold_executive_kpis;


-- ============================================================
-- SECTION B: ORDER AND SALES VALIDATION
-- ============================================================


-- 3. ORDER COUNT RECONCILIATION

WITH silver_orders AS (

    SELECT
        currency,
        COUNT(DISTINCT order_id) AS silver_order_count
    FROM workspace.ecommerce_silver.silver_orders
    GROUP BY currency
),

gold_orders AS (

    SELECT
        currency,
        SUM(total_orders) AS gold_order_count
    FROM workspace.ecommerce_gold.gold_daily_sales
    GROUP BY currency
)

SELECT
    s.currency,
    s.silver_order_count,
    COALESCE(g.gold_order_count, 0) AS gold_order_count,

    s.silver_order_count - COALESCE(g.gold_order_count, 0)
        AS order_count_difference,

    CASE
        WHEN s.silver_order_count = COALESCE(g.gold_order_count, 0)
        THEN 'MATCH'
        ELSE 'MISMATCH'
    END AS validation_status

FROM silver_orders s

LEFT JOIN gold_orders g
    ON s.currency = g.currency

ORDER BY s.currency;


-- 4. NON-CANCELLED ORDER VALUE RECONCILIATION

WITH silver_sales AS (

    SELECT
        currency,

        SUM(
            CASE
                WHEN order_status != 'CANCELLED'
                THEN order_total
                ELSE 0
            END
        ) AS silver_order_value

    FROM workspace.ecommerce_silver.silver_orders

    GROUP BY currency
),

gold_sales AS (

    SELECT
        currency,
        SUM(gross_order_value) AS gold_order_value

    FROM workspace.ecommerce_gold.gold_daily_sales

    GROUP BY currency
)

SELECT
    s.currency,
    s.silver_order_value,
    g.gold_order_value,

    s.silver_order_value - g.gold_order_value
        AS revenue_difference,

    CASE
        WHEN ABS(s.silver_order_value - g.gold_order_value) <= 0.02
        THEN 'MATCH'
        ELSE 'MISMATCH'
    END AS validation_status

FROM silver_sales s

JOIN gold_sales g
    ON s.currency = g.currency

ORDER BY s.currency;


-- 5. CANCELLED ORDER VALIDATION

SELECT
    currency,
    COUNT(*) AS cancelled_order_count,
    SUM(order_total) AS cancelled_order_value

FROM workspace.ecommerce_silver.silver_orders

WHERE order_status = 'CANCELLED'

GROUP BY currency;


-- 6. ORDER ITEMS WITHOUT VALID ORDERS

SELECT
    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    oi.quantity,
    oi.line_total

FROM workspace.ecommerce_silver.silver_order_items oi

LEFT ANTI JOIN workspace.ecommerce_silver.silver_orders o

ON oi.order_id = o.order_id;


-- 7. ORDER VALUE VS ORDER ITEM VALUE

WITH item_totals AS (

    SELECT
        order_id,
        SUM(line_total) AS item_total

    FROM workspace.ecommerce_silver.silver_order_items

    GROUP BY order_id
)

SELECT
    o.order_id,
    o.order_total,
    i.item_total,

    o.order_total - COALESCE(i.item_total, 0)
        AS difference

FROM workspace.ecommerce_silver.silver_orders o

LEFT JOIN item_totals i
    ON o.order_id = i.order_id

WHERE o.order_status != 'CANCELLED'
  AND ABS(
        o.order_total - COALESCE(i.item_total, 0)
      ) > 0.02

ORDER BY ABS(
    o.order_total - COALESCE(i.item_total, 0)
) DESC;


-- ============================================================
-- SECTION C: PAYMENT VALIDATION
-- ============================================================


-- 8. PAYMENT STATUS TOTALS

SELECT
    payment_status,
    COUNT(*) AS payment_count,
    SUM(amount) AS total_amount

FROM workspace.ecommerce_silver.silver_payments

GROUP BY payment_status

ORDER BY payment_count DESC;


-- 9. PAYMENT RECORDS WITHOUT ORDERS

SELECT
    p.payment_id,
    p.order_id,
    p.payment_status,
    p.amount

FROM workspace.ecommerce_silver.silver_payments p

LEFT ANTI JOIN workspace.ecommerce_silver.silver_orders o

ON p.order_id = o.order_id;


-- 10. ORDERS WITHOUT SUCCESSFUL PAYMENTS

SELECT
    o.order_id,
    o.order_total,
    o.currency,
    o.order_status

FROM workspace.ecommerce_silver.silver_orders o

LEFT ANTI JOIN (

    SELECT DISTINCT order_id

    FROM workspace.ecommerce_silver.silver_payments

    WHERE payment_status = 'SUCCESS'

) p

ON o.order_id = p.order_id

WHERE o.order_status != 'CANCELLED';


-- 11. PAYMENT AMOUNT GREATER THAN ORDER VALUE

WITH successful_payments AS (

    SELECT
        order_id,
        SUM(amount) AS successful_amount

    FROM workspace.ecommerce_silver.silver_payments

    WHERE payment_status = 'SUCCESS'

    GROUP BY order_id
)

SELECT
    o.order_id,
    o.order_total,
    p.successful_amount,

    p.successful_amount - o.order_total
        AS excess_payment_amount

FROM workspace.ecommerce_silver.silver_orders o

JOIN successful_payments p
    ON o.order_id = p.order_id

WHERE p.successful_amount > o.order_total;


-- ============================================================
-- SECTION D: CUSTOMER AND PRODUCT VALIDATION
-- ============================================================


-- 12. CUSTOMER COUNT RECONCILIATION

SELECT
    (SELECT COUNT(*)
     FROM workspace.ecommerce_silver.silver_customers)
        AS silver_customer_count,

    (SELECT COUNT(DISTINCT customer_id)
     FROM workspace.ecommerce_gold.gold_customer_lifetime_value)
        AS gold_customer_count;


-- 13. CUSTOMERS WITHOUT GOLD ANALYTICS RECORDS

SELECT
    c.customer_id,
    c.email

FROM workspace.ecommerce_silver.silver_customers c

LEFT ANTI JOIN workspace.ecommerce_gold.gold_customer_lifetime_value g

ON c.customer_id = g.customer_id;


-- 14. PRODUCT COUNT RECONCILIATION

SELECT
    (SELECT COUNT(*)
     FROM workspace.ecommerce_silver.silver_products)
        AS silver_product_count,

    (SELECT COUNT(DISTINCT product_id)
     FROM workspace.ecommerce_gold.gold_product_performance)
        AS gold_product_count;


-- 15. PRODUCTS WITHOUT GOLD ANALYTICS RECORDS

SELECT
    p.product_id,
    p.product_name,
    p.category

FROM workspace.ecommerce_silver.silver_products p

LEFT ANTI JOIN workspace.ecommerce_gold.gold_product_performance g

ON p.product_id = g.product_id;


-- 16. PRODUCT REVENUE RECONCILIATION

WITH silver_product_revenue AS (

    SELECT
        oi.product_id,
        SUM(oi.line_total) AS silver_revenue

    FROM workspace.ecommerce_silver.silver_order_items oi

    INNER JOIN workspace.ecommerce_silver.silver_orders o
        ON oi.order_id = o.order_id

    WHERE o.order_status != 'CANCELLED'

    GROUP BY oi.product_id
)

SELECT
    g.product_id,
    g.total_revenue AS gold_revenue,
    COALESCE(s.silver_revenue, 0) AS silver_revenue,

    g.total_revenue - COALESCE(s.silver_revenue, 0)
        AS revenue_difference

FROM workspace.ecommerce_gold.gold_product_performance g

LEFT JOIN silver_product_revenue s
    ON g.product_id = s.product_id

WHERE ABS(
    g.total_revenue - COALESCE(s.silver_revenue, 0)
) > 0.02;


-- ============================================================
-- SECTION E: INVENTORY VALIDATION
-- ============================================================


-- 17. NEGATIVE INVENTORY CHECK

SELECT
    product_id,
    warehouse_id,
    snapshot_date,
    quantity_on_hand

FROM workspace.ecommerce_silver.silver_inventory

WHERE quantity_on_hand < 0;


-- 18. DUPLICATE INVENTORY BUSINESS KEYS

SELECT
    product_id,
    warehouse_id,
    snapshot_date,
    COUNT(*) AS duplicate_count

FROM workspace.ecommerce_silver.silver_inventory

GROUP BY
    product_id,
    warehouse_id,
    snapshot_date

HAVING COUNT(*) > 1;


-- 19. INVENTORY PRODUCT REFERENCES

SELECT
    i.product_id,
    i.warehouse_id,
    i.snapshot_date

FROM workspace.ecommerce_silver.silver_inventory i

LEFT ANTI JOIN workspace.ecommerce_silver.silver_products p

ON i.product_id = p.product_id;


-- ============================================================
-- SECTION F: SHIPPING VALIDATION
-- ============================================================


-- 20. SHIPMENTS WITHOUT VALID ORDERS

SELECT
    s.shipment_id,
    s.order_id,
    s.carrier,
    s.shipment_status

FROM workspace.ecommerce_silver.silver_shipments s

LEFT ANTI JOIN workspace.ecommerce_silver.silver_orders o

ON s.order_id = o.order_id;


-- 21. INVALID DELIVERY DATES

SELECT
    shipment_id,
    order_id,
    shipped_date,
    delivered_date

FROM workspace.ecommerce_silver.silver_shipments

WHERE delivered_date < shipped_date;


-- 22. DELIVERED SHIPMENTS WITHOUT DELIVERY DATE

SELECT
    shipment_id,
    order_id,
    shipment_status,
    shipped_date,
    delivered_date

FROM workspace.ecommerce_silver.silver_shipments

WHERE shipment_status = 'DELIVERED'
  AND delivered_date IS NULL;


-- ============================================================
-- SECTION G: DUPLICATE AND NULL VALIDATION
-- ============================================================


-- 23. DUPLICATE CUSTOMER IDs

SELECT
    customer_id,
    COUNT(*) AS duplicate_count

FROM workspace.ecommerce_silver.silver_customers

GROUP BY customer_id

HAVING COUNT(*) > 1;


-- 24. DUPLICATE PRODUCT IDs

SELECT
    product_id,
    COUNT(*) AS duplicate_count

FROM workspace.ecommerce_silver.silver_products

GROUP BY product_id

HAVING COUNT(*) > 1;


-- 25. DUPLICATE ORDER IDs

SELECT
    order_id,
    COUNT(*) AS duplicate_count

FROM workspace.ecommerce_silver.silver_orders

GROUP BY order_id

HAVING COUNT(*) > 1;


-- 26. NULL BUSINESS KEYS

SELECT
    'customers' AS dataset_name,
    COUNT_IF(customer_id IS NULL) AS null_key_count
FROM workspace.ecommerce_silver.silver_customers

UNION ALL

SELECT
    'products',
    COUNT_IF(product_id IS NULL)
FROM workspace.ecommerce_silver.silver_products

UNION ALL

SELECT
    'orders',
    COUNT_IF(order_id IS NULL)
FROM workspace.ecommerce_silver.silver_orders

UNION ALL

SELECT
    'order_items',
    COUNT_IF(order_item_id IS NULL)
FROM workspace.ecommerce_silver.silver_order_items

UNION ALL

SELECT
    'payments',
    COUNT_IF(payment_id IS NULL)
FROM workspace.ecommerce_silver.silver_payments

UNION ALL

SELECT
    'shipments',
    COUNT_IF(shipment_id IS NULL)
FROM workspace.ecommerce_silver.silver_shipments;


-- ============================================================
-- SECTION H: DASHBOARD READINESS
-- ============================================================


-- 27. GOLD TABLE AVAILABILITY

SHOW TABLES IN workspace.ecommerce_gold;


-- 28. DATA QUALITY REPORT AVAILABILITY

SHOW TABLES IN workspace.ecommerce_silver;


-- 29. EXECUTIVE KPI VALIDATION

SELECT *
FROM workspace.ecommerce_gold.gold_executive_kpis
ORDER BY currency;


-- 30. FINAL DASHBOARD READINESS SUMMARY

SELECT
    'Daily Sales' AS dashboard_name,
    COUNT(*) AS available_records,
    CASE
        WHEN COUNT(*) > 0 THEN 'READY'
        ELSE 'NOT READY'
    END AS dashboard_status
FROM workspace.ecommerce_gold.gold_daily_sales

UNION ALL

SELECT
    'Customer Analytics',
    COUNT(*),
    CASE WHEN COUNT(*) > 0 THEN 'READY' ELSE 'NOT READY' END
FROM workspace.ecommerce_gold.gold_customer_lifetime_value

UNION ALL

SELECT
    'Product Analytics',
    COUNT(*),
    CASE WHEN COUNT(*) > 0 THEN 'READY' ELSE 'NOT READY' END
FROM workspace.ecommerce_gold.gold_product_performance

UNION ALL

SELECT
    'Payment Analytics',
    COUNT(*),
    CASE WHEN COUNT(*) > 0 THEN 'READY' ELSE 'NOT READY' END
FROM workspace.ecommerce_gold.gold_payment_metrics

UNION ALL

SELECT
    'Shipping Analytics',
    COUNT(*),
    CASE WHEN COUNT(*) > 0 THEN 'READY' ELSE 'NOT READY' END
FROM workspace.ecommerce_gold.gold_shipping_metrics

UNION ALL

SELECT
    'Inventory Analytics',
    COUNT(*),
    CASE WHEN COUNT(*) > 0 THEN 'READY' ELSE 'NOT READY' END
FROM workspace.ecommerce_gold.gold_inventory_status

UNION ALL

SELECT
    'Executive Dashboard',
    COUNT(*),
    CASE WHEN COUNT(*) > 0 THEN 'READY' ELSE 'NOT READY' END
FROM workspace.ecommerce_gold.gold_executive_kpis;


-- ============================================================
-- END OF DASHBOARD VALIDATION AND FINAL QUERIES
-- ============================================================
