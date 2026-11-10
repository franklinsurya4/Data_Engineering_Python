-- ============================================================
-- E-COMMERCE LAKEHOUSE
-- FOLDER 08: SQL DASHBOARD QUERIES
-- FILE 01: EXECUTIVE DASHBOARD
-- ============================================================


-- 1. EXECUTIVE KPI CARDS

SELECT
    currency,
    total_orders,
    non_cancelled_orders,
    cancelled_orders,
    unique_purchasing_customers,
    gross_order_value,
    average_order_value,
    order_cancellation_rate,
    net_payment_amount,
    payment_success_rate,
    delivery_rate,
    total_inventory_units,
    low_stock_products,
    out_of_stock_products
FROM workspace.ecommerce_gold.gold_executive_kpis
ORDER BY currency;


-- 2. SALES PERFORMANCE SUMMARY

SELECT
    currency,
    SUM(total_orders) AS total_orders,
    SUM(non_cancelled_orders) AS non_cancelled_orders,
    SUM(cancelled_orders) AS cancelled_orders,
    SUM(gross_order_value) AS gross_order_value,
    SUM(gross_order_value) /
        NULLIF(SUM(non_cancelled_orders), 0) AS average_order_value
FROM workspace.ecommerce_gold.gold_daily_sales
GROUP BY currency
ORDER BY gross_order_value DESC;


-- 3. DAILY SALES TREND

SELECT
    order_date,
    currency,
    total_orders,
    non_cancelled_orders,
    gross_order_value,
    average_order_value,
    total_units_sold,
    delivered_orders,
    cancelled_orders
FROM workspace.ecommerce_gold.gold_daily_sales
ORDER BY order_date, currency;


-- 4. MONTHLY SALES TREND

SELECT
    DATE_FORMAT(order_date, 'yyyy-MM') AS sales_month,
    currency,
    SUM(gross_order_value) AS monthly_sales,
    SUM(total_orders) AS total_orders,
    SUM(non_cancelled_orders) AS non_cancelled_orders,
    SUM(cancelled_orders) AS cancelled_orders,
    SUM(total_units_sold) AS units_sold,
    SUM(gross_order_value) /
        NULLIF(SUM(non_cancelled_orders), 0) AS average_order_value
FROM workspace.ecommerce_gold.gold_daily_sales
GROUP BY
    DATE_FORMAT(order_date, 'yyyy-MM'),
    currency
ORDER BY sales_month, currency;


-- 5. SALES BY CHANNEL

SELECT
    sales_channel,
    currency,
    SUM(channel_total_orders) AS total_orders,
    SUM(channel_sales_value) AS total_sales
FROM workspace.ecommerce_gold.gold_channel_daily_sales
GROUP BY
    sales_channel,
    currency
ORDER BY total_sales DESC;


-- 6. TOP 10 PRODUCTS BY REVENUE

SELECT
    product_id,
    product_name,
    category,
    total_units_sold,
    total_revenue,
    estimated_gross_profit,
    estimated_profit_margin_percentage,
    category_revenue_rank
FROM workspace.ecommerce_gold.gold_product_performance
ORDER BY total_revenue DESC
LIMIT 10;


-- 7. CATEGORY PERFORMANCE

SELECT
    category,
    SUM(total_units_sold) AS total_units_sold,
    SUM(total_revenue) AS total_revenue,
    SUM(estimated_gross_profit) AS estimated_gross_profit,
    SUM(estimated_gross_profit) * 100.0 /
        NULLIF(SUM(total_revenue), 0) AS estimated_margin_percentage
FROM workspace.ecommerce_gold.gold_category_performance
GROUP BY category
ORDER BY total_revenue DESC;


-- 8. CUSTOMER LIFETIME VALUE

SELECT
    customer_id,
    first_name,
    last_name,
    total_orders,
    total_order_value,
    net_collected_payment,
    historical_customer_lifetime_value,
    customer_segment,
    currency
FROM workspace.ecommerce_gold.gold_customer_lifetime_value
ORDER BY historical_customer_lifetime_value DESC
LIMIT 20;


-- 9. CUSTOMER SEGMENT SUMMARY

SELECT
    customer_segment,
    currency,
    SUM(total_customers) AS customer_count,
    SUM(total_order_value) AS total_order_value,
    SUM(net_collected_payment) AS total_net_collected_payment,
    SUM(
        average_customer_lifetime_value * total_customers
    ) / NULLIF(SUM(total_customers), 0)
        AS average_customer_lifetime_value
FROM workspace.ecommerce_gold.gold_customer_segments
GROUP BY
    customer_segment,
    currency
ORDER BY total_order_value DESC;


-- 10. PAYMENT STATUS PERFORMANCE

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


-- 11. PAYMENT METHOD PERFORMANCE

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


-- 12. SHIPPING PERFORMANCE

SELECT
    shipment_date,
    total_shipments,
    delivered_shipments,
    shipped_shipments,
    in_transit_shipments,
    out_for_delivery_shipments,
    processing_shipments,
    pending_shipments,
    cancelled_shipments,
    returned_shipments,
    average_delivery_hours,
    average_delivery_days,
    minimum_delivery_days,
    maximum_delivery_days,
    delivery_rate,
    cancellation_rate,
    return_rate
FROM workspace.ecommerce_gold.gold_shipping_metrics
ORDER BY shipment_date;

-- 13. INVENTORY STATUS

SELECT
    inventory_category,
    COUNT(*) AS total_products,
    SUM(total_quantity_on_hand) AS total_stock_quantity,
    SUM(inventory_cost_value) AS inventory_cost_value,
    SUM(inventory_retail_value) AS inventory_retail_value
FROM workspace.ecommerce_gold.gold_inventory_status
GROUP BY inventory_category
ORDER BY total_products DESC;


-- 14. LOW STOCK PRODUCTS

SELECT
    product_id,
    product_name,
    category,
    total_quantity_on_hand,
    warehouse_count,
    inventory_category
FROM workspace.ecommerce_gold.gold_inventory_status
WHERE inventory_category = 'LOW_STOCK'
ORDER BY total_quantity_on_hand ASC, product_id;


-- 15. OUT OF STOCK PRODUCTS

SELECT
    product_id,
    product_name,
    category,
    total_quantity_on_hand,
    warehouse_count
FROM workspace.ecommerce_gold.gold_inventory_status
WHERE inventory_category = 'OUT_OF_STOCK'
ORDER BY product_name;


-- 16. WAREHOUSE INVENTORY PERFORMANCE

SELECT
    warehouse_id,
    total_products,
    total_quantity_on_hand,
    out_of_stock_product_count,
    low_stock_product_count,
    inventory_cost_value,
    latest_snapshot_date
FROM workspace.ecommerce_gold.gold_warehouse_inventory
ORDER BY total_quantity_on_hand DESC;


-- 17. EXECUTIVE ALERT SUMMARY

SELECT
    currency,
    executive_payment_status,
    executive_delivery_status,
    executive_inventory_status,
    payment_success_rate,
    delivery_rate,
    low_stock_products,
    out_of_stock_products
FROM workspace.ecommerce_gold.gold_executive_kpis
ORDER BY currency;


-- 18. DATA QUALITY OVERVIEW

SELECT *
FROM workspace.ecommerce_silver.data_quality_dashboard_summary;


-- 19. REFERENTIAL INTEGRITY OVERVIEW

SELECT *
FROM workspace.ecommerce_silver.referential_integrity_dashboard_summary;


-- 20. INVENTORY SNAPSHOT TREND

SELECT
    inventory_snapshot_id,
    product_id,
    warehouse_id,
    snapshot_date,
    previous_quantity,
    quantity_on_hand,
    quantity_change,
    quantity_change_type
FROM workspace.ecommerce_gold.gold_inventory_snapshot_trends
ORDER BY snapshot_date, product_id, warehouse_id;


-- ============================================================
-- END OF EXECUTIVE DASHBOARD SQL
-- ============================================================