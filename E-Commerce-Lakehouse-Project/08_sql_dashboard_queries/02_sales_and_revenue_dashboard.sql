-- ============================================================
-- E-COMMERCE LAKEHOUSE
-- FOLDER 08: SQL DASHBOARD QUERIES
-- FILE 02: SALES AND REVENUE DASHBOARD
-- ============================================================

-- 1. DAILY SALES PERFORMANCE

SELECT
    order_date,
    currency,
    total_orders,
    gross_order_value,
    average_order_value,
    total_units_sold,
    delivered_orders,
    cancelled_orders
FROM workspace.ecommerce_gold.gold_daily_sales
ORDER BY order_date, currency;


-- 2. MONTHLY SALES PERFORMANCE

SELECT
    DATE_FORMAT(order_date, 'yyyy-MM') AS sales_month,
    currency,
    SUM(total_orders) AS total_orders,
    SUM(gross_order_value) AS monthly_sales,
    SUM(non_cancelled_orders) AS non_cancelled_orders,
    SUM(gross_order_value) /
        NULLIF(SUM(non_cancelled_orders), 0) AS monthly_aov,
    SUM(total_units_sold) AS total_units_sold
FROM workspace.ecommerce_gold.gold_daily_sales
GROUP BY
    DATE_FORMAT(order_date, 'yyyy-MM'),
    currency
ORDER BY sales_month;


-- 3. WEEKLY SALES PERFORMANCE

SELECT
    YEAR(order_date) AS sales_year,
    WEEKOFYEAR(order_date) AS sales_week,
    currency,
    SUM(total_orders) AS total_orders,
    SUM(gross_order_value) AS weekly_sales,
    SUM(total_units_sold) AS total_units_sold
FROM workspace.ecommerce_gold.gold_daily_sales
GROUP BY
    YEAR(order_date),
    WEEKOFYEAR(order_date),
    currency
ORDER BY sales_year, sales_week;


-- 4. DAILY SALES GROWTH

WITH daily_sales AS (
    SELECT
        order_date,
        currency,
        SUM(gross_order_value) AS daily_revenue
    FROM workspace.ecommerce_gold.gold_daily_sales
    GROUP BY order_date, currency
),
sales_comparison AS (
    SELECT
        order_date,
        currency,
        daily_revenue,
        LAG(daily_revenue) OVER (
            PARTITION BY currency
            ORDER BY order_date
        ) AS previous_day_revenue
    FROM daily_sales
)
SELECT
    order_date,
    currency,
    daily_revenue,
    previous_day_revenue,
    daily_revenue - previous_day_revenue AS revenue_difference,
    CASE
        WHEN previous_day_revenue IS NULL
          OR previous_day_revenue = 0 THEN NULL
        ELSE ROUND(
            (daily_revenue - previous_day_revenue)
            / previous_day_revenue * 100,
            2
        )
    END AS revenue_growth_percentage
FROM sales_comparison
ORDER BY order_date;


-- 5. MONTH-OVER-MONTH SALES GROWTH

WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(order_date, 'yyyy-MM') AS sales_month,
        currency,
        SUM(gross_order_value) AS monthly_revenue
    FROM workspace.ecommerce_gold.gold_daily_sales
    GROUP BY
        DATE_FORMAT(order_date, 'yyyy-MM'),
        currency
),
monthly_comparison AS (
    SELECT
        sales_month,
        currency,
        monthly_revenue,
        LAG(monthly_revenue) OVER (
            PARTITION BY currency
            ORDER BY sales_month
        ) AS previous_month_revenue
    FROM monthly_sales
)
SELECT
    sales_month,
    currency,
    monthly_revenue,
    previous_month_revenue,
    monthly_revenue - previous_month_revenue AS revenue_difference,
    CASE
        WHEN previous_month_revenue IS NULL
          OR previous_month_revenue = 0 THEN NULL
        ELSE ROUND(
            (monthly_revenue - previous_month_revenue)
            / previous_month_revenue * 100,
            2
        )
    END AS mom_growth_percentage
FROM monthly_comparison
ORDER BY sales_month;


-- 6. RUNNING TOTAL SALES

SELECT
    order_date,
    currency,
    gross_order_value,
    SUM(gross_order_value) OVER (
        PARTITION BY currency
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM workspace.ecommerce_gold.gold_daily_sales
ORDER BY order_date;


-- 7. SALES BY CHANNEL

SELECT
    sales_channel,
    currency,
    SUM(channel_total_orders) AS total_orders,
    SUM(channel_sales_value) AS total_revenue
FROM workspace.ecommerce_gold.gold_channel_daily_sales
GROUP BY sales_channel, currency
ORDER BY total_revenue DESC;


-- 8. CHANNEL REVENUE CONTRIBUTION

WITH channel_revenue AS (
    SELECT
        sales_channel,
        currency,
        SUM(channel_sales_value) AS channel_revenue
    FROM workspace.ecommerce_gold.gold_channel_daily_sales
    GROUP BY sales_channel, currency
)
SELECT
    sales_channel,
    currency,
    channel_revenue,
    ROUND(
        channel_revenue /
        NULLIF(
            SUM(channel_revenue) OVER (PARTITION BY currency),
            0
        ) * 100,
        2
    ) AS revenue_contribution_percentage
FROM channel_revenue
ORDER BY currency, channel_revenue DESC;


-- 09. Order Status Distribution

SELECT
    order_status,
    currency,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(order_total) AS total_order_value
FROM workspace.ecommerce_silver.silver_orders
GROUP BY
    order_status,
    currency
ORDER BY
    total_orders DESC;

-- 10. Order Status Percentage

WITH status_summary AS (
    SELECT
        order_status,
        currency,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(order_total) AS total_order_value
    FROM workspace.ecommerce_silver.silver_orders
    GROUP BY
        order_status,
        currency
)

SELECT
    order_status,
    currency,
    total_orders,
    total_order_value,

    ROUND(
        total_orders * 100.0 /
        NULLIF(
            SUM(total_orders) OVER (PARTITION BY currency),
            0
        ),
        2
    ) AS order_percentage

FROM status_summary
ORDER BY
    currency,
    order_percentage DESC;


-- 11. Top 10 Products by Revenue

SELECT
    product_id,
    product_name,
    category,
    total_units_sold,
    total_orders,
    total_revenue,
    estimated_total_cost,
    estimated_gross_profit,
    estimated_profit_margin_percentage,
    performance_category
FROM workspace.ecommerce_gold.gold_product_performance
ORDER BY total_revenue DESC
LIMIT 10;

-- 12. Top 3 Products in Each Category

WITH ranked_products AS (
    SELECT
        product_id,
        product_name,
        category,
        total_units_sold,
        total_orders,
        total_revenue,
        estimated_gross_profit,
        estimated_profit_margin_percentage,

        DENSE_RANK() OVER (
            PARTITION BY category
            ORDER BY total_revenue DESC
        ) AS revenue_rank

    FROM workspace.ecommerce_gold.gold_product_performance
)

SELECT
    product_id,
    product_name,
    category,
    total_units_sold,
    total_orders,
    total_revenue,
    estimated_gross_profit,
    estimated_profit_margin_percentage,
    revenue_rank
FROM ranked_products
WHERE revenue_rank <= 3
ORDER BY category, revenue_rank, total_revenue DESC;

-- 13. Category Revenue Contribution

SELECT
    category,
    total_products,
    total_units_sold,
    total_revenue,
    estimated_total_cost,
    estimated_gross_profit,
    estimated_profit_margin_percentage,

    ROUND(
        total_revenue * 100.0 /
        NULLIF(SUM(total_revenue) OVER (), 0),
        2
    ) AS revenue_contribution_percentage

FROM workspace.ecommerce_gold.gold_category_performance

ORDER BY total_revenue DESC;

-- 14. Top 10 Sales Days

SELECT
    order_date,
    currency,
    total_orders,
    non_cancelled_orders,
    gross_order_value,
    total_units_sold,
    delivered_orders,
    cancelled_orders,
    average_order_value
FROM workspace.ecommerce_gold.gold_daily_sales
ORDER BY gross_order_value DESC
LIMIT 10;

-- 15. Lowest 10 Sales Days

SELECT
    order_date,
    currency,
    total_orders,
    non_cancelled_orders,
    gross_order_value,
    total_units_sold,
    average_order_value
FROM workspace.ecommerce_gold.gold_daily_sales
WHERE non_cancelled_orders > 0
ORDER BY gross_order_value ASC
LIMIT 10;

-- 16. Month-to-Date Sales (Latest Available Dataset Month)

WITH latest_date AS (
    SELECT MAX(order_date) AS max_order_date
    FROM workspace.ecommerce_gold.gold_daily_sales
)

SELECT
    d.currency,
    MIN(d.order_date) AS period_start_date,
    MAX(d.order_date) AS latest_order_date,
    SUM(d.total_orders) AS total_orders,
    SUM(d.non_cancelled_orders) AS non_cancelled_orders,
    SUM(d.cancelled_orders) AS cancelled_orders,
    SUM(d.gross_order_value) AS month_to_date_sales,
    SUM(d.total_units_sold) AS total_units_sold,

    ROUND(
        SUM(d.gross_order_value) /
        NULLIF(SUM(d.non_cancelled_orders), 0),
        2
    ) AS average_order_value

FROM workspace.ecommerce_gold.gold_daily_sales d
CROSS JOIN latest_date l
WHERE d.order_date >= DATE_TRUNC('MONTH', l.max_order_date)
  AND d.order_date <= l.max_order_date
GROUP BY d.currency
ORDER BY month_to_date_sales DESC;

-- 17. Year-to-Date Sales (Latest Available Dataset Year)

WITH latest_date AS (
    SELECT MAX(order_date) AS max_order_date
    FROM workspace.ecommerce_gold.gold_daily_sales
)

SELECT
    d.currency,
    MIN(d.order_date) AS period_start_date,
    MAX(d.order_date) AS latest_order_date,
    SUM(d.total_orders) AS total_orders,
    SUM(d.non_cancelled_orders) AS non_cancelled_orders,
    SUM(d.cancelled_orders) AS cancelled_orders,
    SUM(d.gross_order_value) AS year_to_date_sales,
    SUM(d.total_units_sold) AS total_units_sold,

    ROUND(
        SUM(d.gross_order_value) /
        NULLIF(SUM(d.non_cancelled_orders), 0),
        2
    ) AS average_order_value

FROM workspace.ecommerce_gold.gold_daily_sales d
CROSS JOIN latest_date l
WHERE d.order_date >= DATE_TRUNC('YEAR', l.max_order_date)
  AND d.order_date <= l.max_order_date
GROUP BY d.currency
ORDER BY year_to_date_sales DESC;

-- 18. Sales by Day of Week

SELECT
    DAYOFWEEK(order_date) AS day_number,
    DATE_FORMAT(order_date, 'EEEE') AS day_name,
    currency,
    SUM(total_orders) AS total_orders,
    SUM(non_cancelled_orders) AS non_cancelled_orders,
    SUM(gross_order_value) AS total_sales,
    SUM(total_units_sold) AS total_units_sold

FROM workspace.ecommerce_gold.gold_daily_sales
GROUP BY
    DAYOFWEEK(order_date),
    DATE_FORMAT(order_date, 'EEEE'),
    currency

ORDER BY
    day_number,
    currency;

-- 19. Sales by Currency

SELECT
    currency,
    SUM(total_orders) AS total_orders,
    SUM(non_cancelled_orders) AS non_cancelled_orders,
    SUM(cancelled_orders) AS cancelled_orders,
    SUM(gross_order_value) AS total_revenue,
    SUM(total_units_sold) AS total_units_sold,

    ROUND(
        SUM(gross_order_value) /
        NULLIF(SUM(non_cancelled_orders), 0),
        2
    ) AS average_order_value

FROM workspace.ecommerce_gold.gold_daily_sales
GROUP BY currency
ORDER BY total_revenue DESC;


-- 20. Sales Reconciliation: Gold vs Silver

WITH silver_daily_sales AS (
    SELECT
        CAST(order_timestamp AS DATE) AS order_date,
        currency,

        COUNT(DISTINCT order_id) AS silver_total_orders,

        COUNT(DISTINCT CASE
            WHEN LOWER(order_status) <> 'cancelled'
            THEN order_id
        END) AS silver_non_cancelled_orders,

        COUNT(DISTINCT CASE
            WHEN LOWER(order_status) = 'cancelled'
            THEN order_id
        END) AS silver_cancelled_orders,

        SUM(order_total) AS silver_gross_order_value

    FROM workspace.ecommerce_silver.silver_orders
    GROUP BY
        CAST(order_timestamp AS DATE),
        currency
),

gold_daily_sales AS (
    SELECT
        order_date,
        currency,
        total_orders AS gold_total_orders,
        non_cancelled_orders AS gold_non_cancelled_orders,
        cancelled_orders AS gold_cancelled_orders,
        gross_order_value AS gold_gross_order_value

    FROM workspace.ecommerce_gold.gold_daily_sales
)

SELECT
    COALESCE(g.order_date, s.order_date) AS order_date,
    COALESCE(g.currency, s.currency) AS currency,

    g.gold_total_orders,
    s.silver_total_orders,

    g.gold_non_cancelled_orders,
    s.silver_non_cancelled_orders,

    g.gold_cancelled_orders,
    s.silver_cancelled_orders,

    g.gold_gross_order_value,
    s.silver_gross_order_value,

    COALESCE(g.gold_total_orders, 0)
        - COALESCE(s.silver_total_orders, 0)
        AS order_count_difference,

    ROUND(
        COALESCE(g.gold_gross_order_value, 0)
        - COALESCE(s.silver_gross_order_value, 0),
        2
    ) AS revenue_difference,

    CASE
        WHEN g.order_date IS NULL THEN 'MISSING IN GOLD'
        WHEN s.order_date IS NULL THEN 'MISSING IN SILVER'
        WHEN g.gold_total_orders = s.silver_total_orders
         AND g.gold_gross_order_value = s.silver_gross_order_value
        THEN 'MATCHED'
        ELSE 'MISMATCH'
    END AS reconciliation_status

FROM gold_daily_sales g

FULL OUTER JOIN silver_daily_sales s
    ON g.order_date = s.order_date
   AND g.currency = s.currency

ORDER BY
    order_date,
    currency;    



%sql

DESCRIBE TABLE workspace.ecommerce_silver.silver_orders;

DESCRIBE TABLE workspace.ecommerce_gold.gold_daily_sales;

DESCRIBE TABLE workspace.ecommerce_gold.gold_product_performance;

DESCRIBE TABLE workspace.ecommerce_gold.gold_category_performance;