-- ============================================================
-- E-COMMERCE LAKEHOUSE
-- FOLDER 08: SQL DASHBOARD QUERIES
-- FILE 05: INVENTORY AND DATA QUALITY DASHBOARD
-- ============================================================


-- ============================================================
-- SECTION A: INVENTORY ANALYTICS
-- ============================================================


-- 1. OVERALL INVENTORY SUMMARY

SELECT
    COUNT(DISTINCT product_id) AS total_products,
    SUM(total_quantity_on_hand) AS total_stock_quantity,
    SUM(inventory_cost_value) AS total_inventory_cost_value,
    SUM(inventory_retail_value) AS total_inventory_retail_value
FROM workspace.ecommerce_gold.gold_inventory_status;


-- 2. INVENTORY STATUS DISTRIBUTION

SELECT
    stock_status,
    COUNT(DISTINCT product_id) AS product_count,
    SUM(total_quantity_on_hand) AS total_quantity
FROM workspace.ecommerce_gold.gold_inventory_status
GROUP BY stock_status
ORDER BY product_count DESC;


-- 3. LOW STOCK PRODUCTS

SELECT
    product_id,
    product_name,
    inventory_category,
    total_quantity_on_hand,
    stock_status
FROM workspace.ecommerce_gold.gold_inventory_status
WHERE UPPER(TRIM(stock_status)) = 'LOW_STOCK'
ORDER BY total_quantity_on_hand ASC;


-- 4. OUT OF STOCK PRODUCTS

SELECT
    product_id,
    product_name,
    inventory_category,
    total_quantity_on_hand,
    stock_status
FROM workspace.ecommerce_gold.gold_inventory_status
WHERE UPPER(TRIM(stock_status)) = 'OUT_OF_STOCK'
ORDER BY product_name;


-- 5. INVENTORY VALUATION BY CATEGORY

SELECT
    inventory_category,
    COUNT(DISTINCT product_id) AS total_products,
    SUM(total_quantity_on_hand) AS total_stock_quantity,
    SUM(inventory_cost_value) AS total_cost_value,
    SUM(inventory_retail_value) AS total_retail_value
FROM workspace.ecommerce_gold.gold_inventory_status
GROUP BY inventory_category
ORDER BY total_cost_value DESC;


-- 6. Overall warehouse inventory summary

SELECT
    COUNT(DISTINCT warehouse_id) AS total_warehouses,
    SUM(total_products) AS total_products,
    SUM(total_quantity_on_hand) AS total_stock_quantity,
    SUM(out_of_stock_product_count) AS out_of_stock_products,
    SUM(low_stock_product_count) AS low_stock_products,
    SUM(inventory_cost_value) AS total_inventory_cost_value
FROM workspace.ecommerce_gold.gold_warehouse_inventory;


-- 7. WAREHOUSE LOW STOCK ANALYSIS

SELECT
    warehouse_id,
    total_products,
    low_stock_product_count,
    total_quantity_on_hand,
    latest_snapshot_date
FROM workspace.ecommerce_gold.gold_warehouse_inventory
WHERE low_stock_product_count > 0
ORDER BY low_stock_product_count DESC;


-- 8. WAREHOUSE OUT OF STOCK ANALYSIS

SELECT
    warehouse_id,
    total_products,
    out_of_stock_product_count,
    total_quantity_on_hand,
    latest_snapshot_date
FROM workspace.ecommerce_gold.gold_warehouse_inventory
WHERE out_of_stock_product_count > 0
ORDER BY out_of_stock_product_count DESC;


-- 9. PRODUCT INVENTORY VALUE RANKING

SELECT
    product_id,
    product_name,
    inventory_category,
    total_quantity_on_hand,
    inventory_cost_value,
    DENSE_RANK() OVER (
        ORDER BY inventory_cost_value DESC
    ) AS inventory_value_rank
FROM workspace.ecommerce_gold.gold_inventory_status
ORDER BY inventory_value_rank;


-- 10. INVENTORY SNAPSHOT HISTORY

SELECT
    product_id,
    warehouse_id,
    snapshot_date,
    quantity_on_hand,
    previous_quantity,
    quantity_change,
    quantity_change_type
FROM workspace.ecommerce_gold.gold_inventory_snapshot_trends
ORDER BY product_id, warehouse_id, snapshot_date;


-- 11. INVENTORY CHANGE ANALYSIS

SELECT
    product_id,
    warehouse_id,
    snapshot_date,
    quantity_on_hand,
    previous_quantity,
    quantity_change,

    CASE
        WHEN quantity_change > 0 THEN 'STOCK INCREASE'
        WHEN quantity_change < 0 THEN 'STOCK DECREASE'
        ELSE 'NO CHANGE'
    END AS stock_movement

FROM workspace.ecommerce_gold.gold_inventory_snapshot_trends
ORDER BY snapshot_date DESC;


-- 12. INVENTORY ALERTS

SELECT *
FROM workspace.ecommerce_gold.gold_inventory_alerts;


-- 13. PRODUCTS WITH ZERO INVENTORY

SELECT
    product_id,
    product_name,
    inventory_category,
    total_quantity_on_hand,
    stock_status
FROM workspace.ecommerce_gold.gold_inventory_status
WHERE total_quantity_on_hand = 0
ORDER BY inventory_category, product_name;


-- ============================================================
-- SECTION B: DATA QUALITY ANALYTICS
-- ============================================================


-- 14. DATA QUALITY SUMMARY

SELECT *
FROM workspace.ecommerce_silver.data_quality_dashboard_summary;


-- 15. DATA QUALITY DETAIL REPORT

SELECT *
FROM workspace.ecommerce_silver.data_quality_dashboard_detail;


-- 16. FAILED DATA QUALITY CHECKS

SELECT *
FROM workspace.ecommerce_silver.data_quality_dashboard_detail
WHERE UPPER(TRIM(status)) = 'FAILED';


-- 17. DATA QUALITY PASS RATE BY DATASET

SELECT *
FROM workspace.ecommerce_silver.data_quality_dashboard_summary;


-- 18. DATA QUALITY REPORT HISTORY

SELECT *
FROM workspace.ecommerce_silver.data_quality_report;


-- 19. QUARANTINE SUMMARY

SELECT *
FROM workspace.ecommerce_silver.quarantine_summary;


-- 20. QUARANTINED RECORDS BY DATASET

SELECT
    _quarantine_dataset AS dataset_name,
    COUNT(*) AS quarantined_record_count
FROM workspace.ecommerce_silver.quarantine_records
GROUP BY _quarantine_dataset
ORDER BY quarantined_record_count DESC;


-- 21. QUARANTINE REASON DISTRIBUTION

SELECT
    _quarantine_dataset AS dataset_name,
    _quarantine_reason AS quarantine_reason,
    COUNT(*) AS affected_record_count
FROM workspace.ecommerce_silver.quarantine_records
GROUP BY
    _quarantine_dataset,
    _quarantine_reason
ORDER BY affected_record_count DESC;


-- 22. QUARANTINE HISTORY

SELECT *
FROM workspace.ecommerce_silver.quarantine_history;


-- ============================================================
-- SECTION C: REFERENTIAL INTEGRITY ANALYTICS
-- ============================================================


-- 23. REFERENTIAL INTEGRITY SUMMARY

SELECT
    SUM(total_relationships) AS total_relationships,
    SUM(total_parent_records) AS total_parent_records,
    SUM(total_child_records) AS total_child_records,
    MAX(dashboard_generated_at) AS latest_dashboard_generated_at,
    COUNT(DISTINCT dashboard_run_id) AS total_dashboard_runs
FROM workspace.ecommerce_silver.referential_integrity_dashboard_summary;


-- 24. REFERENTIAL INTEGRITY DETAIL

SELECT
    relationship,
    parent_dataset,
    parent_key,
    child_dataset,
    child_key,
    parent_records,
    unique_parent_keys,
    child_records,
    null_child_foreign_keys,
    orphan_child_records,
    referenced_parent_records,
    parents_without_children,
    reference_match_rate,
    parent_usage_rate,
    orphan_percentage,
    null_fk_percentage,
    dashboard_status
FROM workspace.ecommerce_silver.referential_integrity_dashboard_detail
ORDER BY orphan_child_records DESC;

-- 25. FOREIGN KEY RELATIONSHIP REPORT

SELECT
    relationship,
    parent_dataset,
    parent_key,
    child_dataset,
    child_key,
    parent_records,
    unique_parent_keys,
    child_records,
    null_child_foreign_keys,
    orphan_child_records,
    referenced_parent_records,
    parents_without_children,
    checked_at
FROM workspace.ecommerce_silver.foreign_key_relationship_report
ORDER BY orphan_child_records DESC;


-- 26. FOREIGN KEY CARDINALITY REPORT

SELECT
    relationship,
    parent_dataset,
    child_dataset,
    child_key,
    child_key_value,
    child_record_count
FROM workspace.ecommerce_silver.foreign_key_cardinality_report
ORDER BY child_record_count DESC;


-- 27. ORPHAN RECORD QUARANTINE SUMMARY

SELECT
    relationship,
    issue_type,
    quarantine_status,
    COUNT(*) AS orphan_record_count
FROM workspace.ecommerce_silver.orphan_record_quarantine
GROUP BY
    relationship,
    issue_type,
    quarantine_status
ORDER BY orphan_record_count DESC;


-- 28. ORPHAN RECORDS READY FOR REPROCESSING

SELECT
    relationship,
    source_dataset,
    foreign_key_column,
    target_dataset,
    source_record_id,
    invalid_reference_value,
    issue_type,
    quarantine_status,
    detected_at,
    quarantined_at
FROM workspace.ecommerce_silver.orphan_record_quarantine
ORDER BY detected_at DESC;


-- 29. CURRENT REFERENTIAL INTEGRITY FAILURES

SELECT
    relationship,
    parent_dataset,
    parent_key,
    child_dataset,
    child_key,
    orphan_child_records AS orphan_count,
    null_child_foreign_keys AS null_foreign_key_count,
    checked_at
FROM workspace.ecommerce_silver.foreign_key_relationship_report
WHERE orphan_child_records > 0
   OR null_child_foreign_keys > 0
ORDER BY orphan_child_records DESC, checked_at DESC;


-- ============================================================
-- SECTION D: COMBINED MONITORING
-- ============================================================


-- 30. DATA QUALITY AND REFERENTIAL INTEGRITY OVERVIEW

SELECT
    'DATA QUALITY' AS monitoring_area,
    COUNT(*) AS total_report_rows
FROM workspace.ecommerce_silver.data_quality_dashboard_detail

UNION ALL

SELECT
    'REFERENTIAL INTEGRITY' AS monitoring_area,
    COUNT(*) AS total_report_rows
FROM workspace.ecommerce_silver.referential_integrity_dashboard_detail;


-- ============================================================
-- END OF INVENTORY AND DATA QUALITY DASHBOARD
-- ============================================================
