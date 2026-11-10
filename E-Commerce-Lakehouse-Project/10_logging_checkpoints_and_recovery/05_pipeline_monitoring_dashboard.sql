
-- ============================================================
-- E-COMMERCE LAKEHOUSE
-- FOLDER 10: LOGGING, CHECKPOINTS AND RECOVERY
-- FILE 05: PIPELINE MONITORING DASHBOARD
-- ============================================================


-- ============================================================
-- QUERY 01: PIPELINE EXECUTION OVERVIEW
-- ============================================================

SELECT
    pipeline_name,
    COUNT(*) AS total_log_events,

    SUM(
        CASE
            WHEN execution_status = 'SUCCESS'
            THEN 1 ELSE 0
        END
    ) AS successful_events,

    SUM(
        CASE
            WHEN execution_status = 'FAILED'
            THEN 1 ELSE 0
        END
    ) AS failed_events,

    ROUND(
        AVG(duration_seconds),
        2
    ) AS average_duration_seconds

FROM workspace.ecommerce_gold.pipeline_execution_logs

GROUP BY pipeline_name;


-- ============================================================
-- QUERY 02: LATEST PIPELINE EXECUTIONS
-- ============================================================

SELECT
    run_id,
    pipeline_name,
    task_name,
    pipeline_layer,
    execution_status,
    duration_seconds,
    records_read,
    records_processed,
    records_failed,
    logged_at

FROM workspace.ecommerce_gold.pipeline_execution_logs

ORDER BY logged_at DESC

LIMIT 100;


-- ============================================================
-- QUERY 03: SUCCESSFUL TASKS
-- ============================================================

SELECT
    task_name,
    pipeline_layer,
    COUNT(*) AS successful_executions,

    ROUND(
        AVG(duration_seconds),
        2
    ) AS average_duration_seconds

FROM workspace.ecommerce_gold.pipeline_execution_logs

WHERE execution_status = 'SUCCESS'

GROUP BY
    task_name,
    pipeline_layer

ORDER BY successful_executions DESC;


-- ============================================================
-- QUERY 04: FAILED TASKS
-- ============================================================

SELECT
    run_id,
    pipeline_name,
    task_name,
    dataset_name,
    pipeline_layer,
    error_type,
    error_message,
    logged_at

FROM workspace.ecommerce_gold.pipeline_execution_logs

WHERE execution_status = 'FAILED'

ORDER BY logged_at DESC;


-- ============================================================
-- QUERY 05: FAILURE RATE
-- ============================================================

SELECT
    COUNT(*) AS total_log_events,

    SUM(
        CASE
            WHEN execution_status = 'FAILED'
            THEN 1 ELSE 0
        END
    ) AS failed_events,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN execution_status = 'FAILED'
                THEN 1 ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS failure_percentage

FROM workspace.ecommerce_gold.pipeline_execution_logs;


-- ============================================================
-- QUERY 06: LAYER-WISE EXECUTION STATUS
-- ============================================================

SELECT
    pipeline_layer,
    execution_status,
    COUNT(*) AS execution_count

FROM workspace.ecommerce_gold.pipeline_execution_logs

GROUP BY
    pipeline_layer,
    execution_status

ORDER BY
    pipeline_layer,
    execution_status;


-- ============================================================
-- QUERY 07: SLOWEST PIPELINE TASKS
-- ============================================================

SELECT
    task_name,
    pipeline_layer,

    ROUND(
        AVG(duration_seconds),
        2
    ) AS average_duration_seconds,

    MAX(duration_seconds)
        AS maximum_duration_seconds

FROM workspace.ecommerce_gold.pipeline_execution_logs

WHERE execution_status = 'SUCCESS'

GROUP BY
    task_name,
    pipeline_layer

ORDER BY average_duration_seconds DESC;


-- ============================================================
-- QUERY 08: PIPELINE RECORD PROCESSING METRICS
-- ============================================================

SELECT
    pipeline_layer,

    SUM(records_read) AS total_records_read,

    SUM(records_processed) AS total_records_processed,

    SUM(records_failed) AS total_records_failed

FROM workspace.ecommerce_gold.pipeline_execution_logs

GROUP BY pipeline_layer

ORDER BY pipeline_layer;


-- ============================================================
-- QUERY 09: TASK EXECUTION HISTORY
-- ============================================================

SELECT
    task_name,
    run_id,
    execution_status,
    start_timestamp,
    end_timestamp,
    duration_seconds

FROM workspace.ecommerce_gold.pipeline_execution_logs

WHERE task_name <> 'pipeline_execution_summary'

ORDER BY
    task_name,
    logged_at DESC;


-- ============================================================
-- QUERY 10: PIPELINE RUN SUMMARY
-- ============================================================

SELECT
    run_id,
    pipeline_name,

    MAX(
        CASE
            WHEN task_name = 'pipeline_execution_summary'
            THEN execution_status
        END
    ) AS pipeline_status,

    MAX(
        CASE
            WHEN task_name = 'pipeline_execution_summary'
            THEN duration_seconds
        END
    ) AS pipeline_duration_seconds,

    MAX(logged_at) AS last_logged_at

FROM workspace.ecommerce_gold.pipeline_execution_logs

GROUP BY
    run_id,
    pipeline_name

ORDER BY last_logged_at DESC;


-- ============================================================
-- QUERY 11: RETRY EXECUTION REPORT
-- ============================================================

SELECT
    task_name,
    COUNT(*) AS total_error_events,

    SUM(
        CASE
            WHEN retryable = true
            THEN 1 ELSE 0
        END
    ) AS retryable_errors,

    SUM(
        CASE
            WHEN retryable = false
            THEN 1 ELSE 0
        END
    ) AS permanent_errors

FROM workspace.ecommerce_gold.pipeline_error_handling_report

GROUP BY task_name;


-- ============================================================
-- QUERY 12: TASKS THAT EXHAUSTED RETRIES
-- ============================================================

SELECT
    run_id,
    task_name,
    attempt_number,
    max_attempts,
    error_type,
    error_message,
    logged_at

FROM workspace.ecommerce_gold.pipeline_error_handling_report

WHERE execution_status = 'FAILED_MAX_RETRIES'

ORDER BY logged_at DESC;


-- ============================================================
-- QUERY 13: RETRY DELAY ANALYSIS
-- ============================================================

SELECT
    task_name,

    ROUND(
        AVG(retry_delay_seconds),
        2
    ) AS average_retry_delay_seconds,

    MAX(retry_delay_seconds)
        AS maximum_retry_delay_seconds,

    COUNT(*) AS retry_events

FROM workspace.ecommerce_gold.pipeline_error_handling_report

WHERE execution_status = 'RETRY_SCHEDULED'

GROUP BY task_name;


-- ============================================================
-- QUERY 14: ERROR TYPE ANALYSIS
-- ============================================================

SELECT
    error_type,
    COUNT(*) AS error_count

FROM workspace.ecommerce_gold.pipeline_error_handling_report

GROUP BY error_type

ORDER BY error_count DESC;


-- ============================================================
-- QUERY 15: CHECKPOINT VALIDATION OVERVIEW
-- ============================================================

SELECT
    validation_status,

    COUNT(*) AS dataset_count,

    SUM(
        CASE
            WHEN checkpoint_exists = true
            THEN 1 ELSE 0
        END
    ) AS existing_checkpoints,

    SUM(
        CASE
            WHEN checkpoint_exists = false
            THEN 1 ELSE 0
        END
    ) AS missing_checkpoints

FROM workspace.ecommerce_gold.checkpoint_management_report

GROUP BY validation_status;


-- ============================================================
-- QUERY 16: LATEST CHECKPOINT STATUS BY DATASET
-- ============================================================

SELECT
    dataset_name,
    checkpoint_exists,
    checkpoint_file_count,
    checkpoint_size_bytes,
    schema_exists,
    validation_status,
    checked_at

FROM workspace.ecommerce_gold.checkpoint_management_report

QUALIFY ROW_NUMBER() OVER (

    PARTITION BY dataset_name

    ORDER BY checked_at DESC

) = 1

ORDER BY dataset_name;


-- ============================================================
-- QUERY 17: DATASETS WITH MISSING CHECKPOINTS
-- ============================================================

SELECT
    dataset_name,
    checkpoint_path,
    schema_path,
    validation_status,
    error_message

FROM workspace.ecommerce_gold.checkpoint_management_report

QUALIFY ROW_NUMBER() OVER (

    PARTITION BY dataset_name

    ORDER BY checked_at DESC

) = 1

AND checkpoint_exists = false;


-- ============================================================
-- QUERY 18: DATASETS WITH MISSING SCHEMA DIRECTORIES
-- ============================================================

SELECT
    dataset_name,
    schema_path,
    schema_exists,
    validation_status

FROM workspace.ecommerce_gold.checkpoint_management_report

QUALIFY ROW_NUMBER() OVER (

    PARTITION BY dataset_name

    ORDER BY checked_at DESC

) = 1

AND schema_exists = false;


-- ============================================================
-- QUERY 19: RECOVERY ACTION HISTORY
-- ============================================================

SELECT
    failure_id,
    run_id,
    task_name,
    recovery_action,
    recovery_status,
    attempt_number,
    recovery_message,
    recovery_timestamp

FROM workspace.ecommerce_gold.pipeline_recovery_history

ORDER BY recovery_timestamp DESC;


-- ============================================================
-- QUERY 20: RECOVERY ACTION SUMMARY
-- ============================================================

SELECT
    recovery_action,
    recovery_status,
    COUNT(*) AS recovery_count

FROM workspace.ecommerce_gold.pipeline_recovery_history

GROUP BY
    recovery_action,
    recovery_status

ORDER BY recovery_count DESC;


-- ============================================================
-- QUERY 21: BRONZE TABLE HEALTH
-- ============================================================

SELECT
    'BRONZE' AS pipeline_layer,
    'customers' AS dataset_name,
    COUNT(*) AS total_records
FROM workspace.ecommerce_bronze.customers

UNION ALL

SELECT
    'BRONZE',
    'products',
    COUNT(*)
FROM workspace.ecommerce_bronze.products

UNION ALL

SELECT
    'BRONZE',
    'orders',
    COUNT(*)
FROM workspace.ecommerce_bronze.orders

UNION ALL

SELECT
    'BRONZE',
    'order_items',
    COUNT(*)
FROM workspace.ecommerce_bronze.order_items

UNION ALL

SELECT
    'BRONZE',
    'payments',
    COUNT(*)
FROM workspace.ecommerce_bronze.payments

UNION ALL

SELECT
    'BRONZE',
    'shipments',
    COUNT(*)
FROM workspace.ecommerce_bronze.shipments

UNION ALL

SELECT
    'BRONZE',
    'inventory_snapshots',
    COUNT(*)
FROM workspace.ecommerce_bronze.inventory_snapshots;


-- ============================================================
-- QUERY 22: SILVER TABLE HEALTH
-- ============================================================

SELECT
    'SILVER' AS pipeline_layer,
    'silver_customers' AS dataset_name,
    COUNT(*) AS total_records
FROM workspace.ecommerce_silver.silver_customers

UNION ALL

SELECT
    'SILVER',
    'silver_products',
    COUNT(*)
FROM workspace.ecommerce_silver.silver_products

UNION ALL

SELECT
    'SILVER',
    'silver_orders',
    COUNT(*)
FROM workspace.ecommerce_silver.silver_orders

UNION ALL

SELECT
    'SILVER',
    'silver_order_items',
    COUNT(*)
FROM workspace.ecommerce_silver.silver_order_items

UNION ALL

SELECT
    'SILVER',
    'silver_payments',
    COUNT(*)
FROM workspace.ecommerce_silver.silver_payments

UNION ALL

SELECT
    'SILVER',
    'silver_shipments',
    COUNT(*)
FROM workspace.ecommerce_silver.silver_shipments

UNION ALL

SELECT
    'SILVER',
    'silver_inventory',
    COUNT(*)
FROM workspace.ecommerce_silver.silver_inventory;


-- ============================================================
-- QUERY 23: GOLD TABLE HEALTH
-- ============================================================

SELECT
    'GOLD' AS pipeline_layer,
    'gold_daily_sales' AS dataset_name,
    COUNT(*) AS total_records
FROM workspace.ecommerce_gold.gold_daily_sales

UNION ALL

SELECT
    'GOLD',
    'gold_product_performance',
    COUNT(*)
FROM workspace.ecommerce_gold.gold_product_performance

UNION ALL

SELECT
    'GOLD',
    'gold_customer_lifetime_value',
    COUNT(*)
FROM workspace.ecommerce_gold.gold_customer_lifetime_value

UNION ALL

SELECT
    'GOLD',
    'gold_payment_metrics',
    COUNT(*)
FROM workspace.ecommerce_gold.gold_payment_metrics

UNION ALL

SELECT
    'GOLD',
    'gold_shipping_metrics',
    COUNT(*)
FROM workspace.ecommerce_gold.gold_shipping_metrics

UNION ALL

SELECT
    'GOLD',
    'gold_inventory_status',
    COUNT(*)
FROM workspace.ecommerce_gold.gold_inventory_status

UNION ALL

SELECT
    'GOLD',
    'gold_executive_kpis',
    COUNT(*)
FROM workspace.ecommerce_gold.gold_executive_kpis;


-- ============================================================
-- QUERY 24: CURRENT PIPELINE ERROR SUMMARY
-- ============================================================

SELECT
    execution_status,
    COUNT(*) AS total_events

FROM workspace.ecommerce_gold.pipeline_execution_logs

GROUP BY execution_status;


-- ============================================================
-- QUERY 25: PIPELINE MONITORING KPI SUMMARY
-- ============================================================

SELECT

    COUNT(DISTINCT run_id)
        AS total_pipeline_runs,

    COUNT(*) AS total_log_events,

    SUM(
        CASE
            WHEN execution_status = 'SUCCESS'
            THEN 1 ELSE 0
        END
    ) AS successful_log_events,

    SUM(
        CASE
            WHEN execution_status = 'FAILED'
            THEN 1 ELSE 0
        END
    ) AS failed_log_events,

    ROUND(
        AVG(duration_seconds),
        2
    ) AS average_event_duration_seconds

FROM workspace.ecommerce_gold.pipeline_execution_logs;


-- ============================================================
-- QUERY 26: DAILY PIPELINE EXECUTION TREND
-- ============================================================

SELECT
    CAST(logged_at AS DATE) AS execution_date,

    COUNT(DISTINCT run_id)
        AS pipeline_runs,

    SUM(
        CASE
            WHEN execution_status = 'SUCCESS'
            THEN 1 ELSE 0
        END
    ) AS successful_events,

    SUM(
        CASE
            WHEN execution_status = 'FAILED'
            THEN 1 ELSE 0
        END
    ) AS failed_events

FROM workspace.ecommerce_gold.pipeline_execution_logs

GROUP BY CAST(logged_at AS DATE)

ORDER BY execution_date;


-- ============================================================
-- QUERY 27: PIPELINE LAYER DURATION
-- ============================================================

SELECT
    pipeline_layer,

    ROUND(
        AVG(duration_seconds),
        2
    ) AS average_duration_seconds,

    MAX(duration_seconds)
        AS maximum_duration_seconds,

    MIN(duration_seconds)
        AS minimum_duration_seconds

FROM workspace.ecommerce_gold.pipeline_execution_logs

WHERE duration_seconds IS NOT NULL

GROUP BY pipeline_layer

ORDER BY average_duration_seconds DESC;


-- ============================================================
-- QUERY 28: DATASET-LEVEL FAILURE ANALYSIS
-- ============================================================

SELECT
    dataset_name,
    pipeline_layer,
    error_type,
    COUNT(*) AS failure_count

FROM workspace.ecommerce_gold.pipeline_execution_logs

WHERE execution_status = 'FAILED'

GROUP BY
    dataset_name,
    pipeline_layer,
    error_type

ORDER BY failure_count DESC;


-- ============================================================
-- QUERY 29: LATEST PIPELINE STATUS
-- ============================================================

WITH latest_runs AS (

    SELECT
        run_id,
        pipeline_name,
        execution_status,
        duration_seconds,
        logged_at,

        ROW_NUMBER() OVER (

            PARTITION BY run_id

            ORDER BY logged_at DESC

        ) AS row_num

    FROM workspace.ecommerce_gold.pipeline_execution_logs

    WHERE task_name = 'pipeline_execution_summary'

)

SELECT
    run_id,
    pipeline_name,
    execution_status AS pipeline_status,
    duration_seconds,
    logged_at

FROM latest_runs

WHERE row_num = 1

ORDER BY logged_at DESC;


-- ============================================================
-- QUERY 30: MONITORING DASHBOARD FINAL SUMMARY
-- ============================================================

SELECT
    'PIPELINE LOGS' AS monitoring_component,

    COUNT(*) AS total_records

FROM workspace.ecommerce_gold.pipeline_execution_logs

UNION ALL

SELECT
    'PIPELINE ERRORS',
    COUNT(*)

FROM workspace.ecommerce_gold.pipeline_error_handling_report

UNION ALL

SELECT
    'CHECKPOINT REPORTS',
    COUNT(*)

FROM workspace.ecommerce_gold.checkpoint_management_report

UNION ALL

SELECT
    'RECOVERY HISTORY',
    COUNT(*)

FROM workspace.ecommerce_gold.pipeline_recovery_history;
