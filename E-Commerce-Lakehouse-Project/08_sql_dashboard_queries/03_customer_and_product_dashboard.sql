
-- ============================================================
-- E-COMMERCE LAKEHOUSE
-- FOLDER 08: SQL DASHBOARD QUERIES
-- FILE 03: CUSTOMER AND PRODUCT DASHBOARD
-- ============================================================


-- 1. CUSTOMER LIFETIME VALUE OVERVIEW

SELECT
    currency,
    COUNT(DISTINCT customer_id) AS total_customers,
    SUM(total_orders) AS total_orders,
    SUM(total_order_value) AS total_order_value,
    SUM(net_collected_payment) AS total_net_collected_payment,
    AVG(net_collected_payment) AS average_customer_lifetime_value
FROM workspace.ecommerce_gold.gold_customer_lifetime_value
GROUP BY currency
ORDER BY total_net_collected_payment DESC;


-- 2. TOP 10 CUSTOMERS BY LIFETIME VALUE

SELECT
    customer_id,
    currency,
    total_orders,
    total_order_value,
    net_collected_payment,
    first_order_date,
    last_order_date
FROM workspace.ecommerce_gold.gold_customer_lifetime_value
ORDER BY net_collected_payment DESC
LIMIT 10;


-- 3. CUSTOMER SEGMENT DISTRIBUTION

SELECT
    customer_segment,
    total_customers,
    total_order_value,
    net_collected_payment,
    average_customer_lifetime_value
FROM workspace.ecommerce_gold.gold_customer_segments
ORDER BY total_customers DESC;


-- 4. CUSTOMER SEGMENT REVENUE CONTRIBUTION

WITH segment_revenue AS (

    SELECT
        customer_segment,
        total_order_value,
        net_collected_payment,
        total_customers
    FROM workspace.ecommerce_gold.gold_customer_segments
)

SELECT
    customer_segment,
    total_customers,
    total_order_value,
    net_collected_payment AS segment_revenue,

    ROUND(
        net_collected_payment * 100.0 /
        NULLIF(SUM(net_collected_payment) OVER (), 0),
        2
    ) AS revenue_contribution_percentage

FROM segment_revenue
ORDER BY segment_revenue DESC;


-- 5. REPEAT PURCHASE CUSTOMERS

SELECT
    currency,
    COUNT(*) AS repeat_purchase_customers,
    SUM(total_orders) AS orders_from_repeat_customers,
    AVG(total_orders) AS average_orders_per_repeat_customer
FROM workspace.ecommerce_gold.gold_customer_lifetime_value
WHERE total_orders > 1
GROUP BY currency
ORDER BY repeat_purchase_customers DESC;


-- 6. ONE-TIME CUSTOMERS

SELECT
    currency,
    COUNT(DISTINCT customer_id) AS one_time_customers,
    SUM(net_collected_payment) AS total_net_collected_payment
FROM workspace.ecommerce_gold.gold_customer_lifetime_value
WHERE total_orders = 1
GROUP BY currency
ORDER BY one_time_customers DESC;


-- 7. CUSTOMERS WITHOUT PURCHASES

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.city,
    c.state,
    c.created_at
FROM workspace.ecommerce_silver.silver_customers c

LEFT ANTI JOIN (
    SELECT DISTINCT customer_id
    FROM workspace.ecommerce_gold.gold_customer_lifetime_value
    WHERE total_orders > 0
) purchased
ON c.customer_id = purchased.customer_id

ORDER BY c.created_at DESC;


-- 8. CUSTOMER PURCHASE FREQUENCY

SELECT
    customer_id,
    currency,
    total_orders,
    purchase_frequency,
    first_order_date,
    last_order_date
FROM workspace.ecommerce_gold.gold_customer_lifetime_value
WHERE total_orders > 0
ORDER BY purchase_frequency DESC;


-- 9. CUSTOMER ORDER VALUE RANKING

SELECT
    customer_id,
    currency,
    total_order_value,

    DENSE_RANK() OVER (
        PARTITION BY currency
        ORDER BY total_order_value DESC
    ) AS customer_revenue_rank

FROM workspace.ecommerce_gold.gold_customer_lifetime_value
ORDER BY currency, customer_revenue_rank;


-- 10. CUSTOMER AVERAGE ORDER VALUE

SELECT
    customer_id,
    currency,
    total_orders,
    total_order_value,

    total_order_value
        / NULLIF(total_orders, 0) AS customer_average_order_value

FROM workspace.ecommerce_gold.gold_customer_lifetime_value
WHERE total_orders > 0
ORDER BY customer_average_order_value DESC;


-- 11. CUSTOMER FIRST AND LAST PURCHASE ANALYSIS

SELECT
    customer_id,
    currency,
    first_order_date,
    last_order_date,

    DATEDIFF(
        last_order_date,
        first_order_date
    ) AS customer_purchase_lifetime_days,

    total_orders,
    net_collected_payment

FROM workspace.ecommerce_gold.gold_customer_lifetime_value
WHERE total_orders > 0
ORDER BY customer_purchase_lifetime_days DESC;


-- 12. CUSTOMER PURCHASE STATUS SUMMARY

SELECT
    currency,
    SUM(total_orders) AS total_orders,
    SUM(delivered_orders) AS delivered_orders,
    SUM(shipped_orders) AS shipped_orders,
    SUM(processing_orders) AS processing_orders
FROM workspace.ecommerce_gold.gold_customer_lifetime_value
GROUP BY currency;


-- ============================================================
-- SECTION B: PRODUCT ANALYTICS
-- ============================================================


-- 13. PRODUCT PERFORMANCE OVERVIEW

SELECT
    category,
    COUNT(DISTINCT product_id) AS total_products,
    SUM(total_units_sold) AS total_units_sold,
    SUM(total_revenue) AS total_revenue,
    SUM(estimated_gross_profit) AS estimated_gross_profit
FROM workspace.ecommerce_gold.gold_product_performance
GROUP BY category
ORDER BY total_revenue DESC;


-- 14. TOP 10 PRODUCTS BY UNITS SOLD

SELECT
    product_id,
    product_name,
    category,
    total_units_sold,
    total_revenue
FROM workspace.ecommerce_gold.gold_product_performance
ORDER BY total_units_sold DESC
LIMIT 10;


-- 15. TOP 10 PRODUCTS BY REVENUE

SELECT
    product_id,
    product_name,
    category,
    total_revenue,
    total_units_sold
FROM workspace.ecommerce_gold.gold_product_performance
ORDER BY total_revenue DESC
LIMIT 10;


-- 16. PRODUCT PROFITABILITY

SELECT
    product_id,
    product_name,
    category,
    total_units_sold,
    total_orders,
    total_revenue,
    estimated_total_cost,
    estimated_gross_profit,
    estimated_profit_margin_percentage
FROM workspace.ecommerce_gold.gold_product_performance
ORDER BY estimated_gross_profit DESC;


-- 17. LOW PROFIT MARGIN PRODUCTS

SELECT
    product_id,
    product_name,
    category,
    total_units_sold,
    total_revenue,
    estimated_gross_profit,
    estimated_profit_margin_percentage
FROM workspace.ecommerce_gold.gold_product_performance
WHERE estimated_profit_margin_percentage < 10
  AND total_units_sold > 0
ORDER BY estimated_profit_margin_percentage ASC;


-- 18. PRODUCTS WITH NO SALES

SELECT
    product_id,
    product_name,
    category,
    unit_price,
    unit_cost,
    total_units_sold,
    total_revenue
FROM workspace.ecommerce_gold.gold_product_performance
WHERE total_units_sold = 0
ORDER BY category, product_name;


-- 19. CATEGORY PERFORMANCE RANKING

SELECT
    category,
    total_revenue,
    total_units_sold,

    DENSE_RANK() OVER (
        ORDER BY total_revenue DESC
    ) AS category_revenue_rank

FROM workspace.ecommerce_gold.gold_category_performance
ORDER BY category_revenue_rank;


-- 20. PRODUCT REVENUE CONTRIBUTION

WITH product_revenue AS (

    SELECT
        product_id,
        product_name,
        category,
        total_revenue
    FROM workspace.ecommerce_gold.gold_product_performance
)

SELECT
    product_id,
    product_name,
    category,
    total_revenue,

    ROUND(
        total_revenue
        / NULLIF(
            SUM(total_revenue) OVER (
                PARTITION BY category
            ),
            0
        ) * 100,
        2
    ) AS category_revenue_contribution_percentage

FROM product_revenue
ORDER BY category, total_revenue DESC;


-- 21. CATEGORY REVENUE CONTRIBUTION

WITH category_revenue AS (

    SELECT
        category,
        SUM(total_revenue) AS category_revenue
    FROM workspace.ecommerce_gold.gold_category_performance
    GROUP BY category
)

SELECT
    category,
    category_revenue,

    ROUND(
        category_revenue
        / NULLIF(SUM(category_revenue) OVER (), 0) * 100,
        2
    ) AS total_revenue_contribution_percentage

FROM category_revenue
ORDER BY category_revenue DESC;


-- 22. AVERAGE SELLING PRICE BY CATEGORY

SELECT
    category,
    AVG(unit_price) AS average_product_price,
    MIN(unit_price) AS minimum_product_price,
    MAX(unit_price) AS maximum_product_price
FROM workspace.ecommerce_silver.silver_products
GROUP BY category
ORDER BY average_product_price DESC;


-- 23. PRODUCT SALES DISTRIBUTION

SELECT
    category,
    COUNT(*) AS total_products,

    SUM(
        CASE
            WHEN total_units_sold > 0 THEN 1
            ELSE 0
        END
    ) AS products_with_sales,

    SUM(
        CASE
            WHEN total_units_sold = 0 THEN 1
            ELSE 0
        END
    ) AS products_without_sales

FROM workspace.ecommerce_gold.gold_product_performance

GROUP BY category
ORDER BY category;


-- 24. PRODUCT REVENUE AND PROFIT RANKING

SELECT
    product_id,
    product_name,
    category,
    total_revenue,
    estimated_gross_profit,

    DENSE_RANK() OVER (
        ORDER BY estimated_gross_profit DESC
    ) AS profit_rank

FROM workspace.ecommerce_gold.gold_product_performance

WHERE total_units_sold > 0

ORDER BY profit_rank;