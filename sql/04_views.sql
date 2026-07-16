-- ============================================
-- Script:    04_views.sql
-- Purpose:   Analytics views for reporting and Power BI consumption
-- Project:   SuperStore Analytics
-- ============================================

USE SuperStoreProject;
GO
SET NOCOUNT ON;
GO

-- ============================================
-- View: gold.vw_sales_summary
-- Purpose: Full star-schema join, row-level grain, for ad-hoc exploration
-- ============================================
IF OBJECT_ID('gold.vw_sales_summary', 'V') IS NOT NULL
    DROP VIEW gold.vw_sales_summary;
GO

CREATE VIEW gold.vw_sales_summary AS
SELECT
    d.full_date,
    d.year,
    d.quarter_name,
    d.month_name,
    d.month_year_label,
    d.day_name,
    d.is_weekend,
    d.is_business_day,
    d.season,
    c.customer_id,
    c.customer_name,
    c.segment,
    p.product_id,
    p.product_name,
    p.category,
    p.sub_category,
    l.city,
    l.state,
    l.region,
    sm.ship_mode,
    sp.person_name AS sales_person,
    f.order_id,
    f.sales,
    f.quantity,
    f.discount,
    f.profit,
    f.unit_price,
    f.profit_margin,
    f.days_to_ship,
    f.is_returned
FROM gold.fact_sales f
JOIN gold.dim_date d ON f.order_date_key = d.date_key
JOIN gold.dim_customer c ON f.customer_key = c.customer_key
JOIN gold.dim_product p ON f.product_key = p.product_key
JOIN gold.dim_location l ON f.location_key = l.location_key
LEFT JOIN gold.dim_ship_mode sm ON f.ship_mode_key = sm.ship_mode_key
LEFT JOIN gold.dim_sales_person sp ON f.sales_person_key = sp.sales_person_key;
GO

-- ============================================
-- View: gold.vw_product_performance
-- Purpose: Product-level sales, profit, and return metrics
-- ============================================
IF OBJECT_ID('gold.vw_product_performance', 'V') IS NOT NULL
    DROP VIEW gold.vw_product_performance;
GO

CREATE VIEW gold.vw_product_performance AS
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.sub_category,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.sales) AS total_sales,
    SUM(f.profit) AS total_profit,
    SUM(f.quantity) AS total_units,
    AVG(f.discount) AS avg_discount,
    AVG(f.unit_price) AS avg_unit_price,
    SUM(f.profit) / NULLIF(SUM(f.sales), 0) * 100 AS profit_margin_pct,
    SUM(CAST(f.is_returned AS INT)) AS total_returns
FROM gold.fact_sales f
JOIN gold.dim_product p ON f.product_key = p.product_key
GROUP BY p.product_id, p.product_name, p.category, p.sub_category;
GO

-- ============================================
-- View: gold.vw_customer_analysis
-- Purpose: Customer-level spend, profit, and segmentation metrics
-- ============================================
IF OBJECT_ID('gold.vw_customer_analysis', 'V') IS NOT NULL
    DROP VIEW gold.vw_customer_analysis;
GO

CREATE VIEW gold.vw_customer_analysis AS
SELECT
    c.customer_id,
    c.customer_name,
    c.segment,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.sales) AS total_spent,
    SUM(f.profit) AS total_profit,
    AVG(f.sales) AS avg_order_value,
    SUM(f.quantity) AS total_units,
    SUM(CAST(f.is_returned AS INT)) AS total_returns
FROM gold.fact_sales f
JOIN gold.dim_customer c ON f.customer_key = c.customer_key
GROUP BY c.customer_id, c.customer_name, c.segment;
GO

-- ============================================
-- View: gold.vw_regional_performance
-- Purpose: Geographic sales performance by region/state/city
-- ============================================
IF OBJECT_ID('gold.vw_regional_performance', 'V') IS NOT NULL
    DROP VIEW gold.vw_regional_performance;
GO

CREATE VIEW gold.vw_regional_performance AS
SELECT
    l.region,
    l.state,
    l.city,
    sp.person_name AS sales_person,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.sales) AS total_sales,
    SUM(f.profit) AS total_profit,
    SUM(f.quantity) AS total_units,
    AVG(f.days_to_ship) AS avg_shipping_days,
    SUM(CAST(f.is_returned AS INT)) AS total_returns
FROM gold.fact_sales f
JOIN gold.dim_location l ON f.location_key = l.location_key
LEFT JOIN gold.dim_sales_person sp ON f.sales_person_key = sp.sales_person_key
GROUP BY l.region, l.state, l.city, sp.person_name;
GO

-- ============================================
-- View: gold.vw_shipping_performance
-- Purpose: Ship mode performance and delivery time metrics
-- ============================================
IF OBJECT_ID('gold.vw_shipping_performance', 'V') IS NOT NULL
    DROP VIEW gold.vw_shipping_performance;
GO

CREATE VIEW gold.vw_shipping_performance AS
SELECT
    sm.ship_mode,
    COUNT(DISTINCT f.order_id) AS total_orders,
    AVG(f.days_to_ship) AS avg_days_to_ship,
    MIN(f.days_to_ship) AS min_days,
    MAX(f.days_to_ship) AS max_days,
    SUM(f.sales) AS total_sales,
    SUM(CAST(f.is_returned AS INT)) AS total_returns
FROM gold.fact_sales f
LEFT JOIN gold.dim_ship_mode sm ON f.ship_mode_key = sm.ship_mode_key
GROUP BY sm.ship_mode;
GO

-- ============================================
-- View: gold.vw_monthly_trends
-- Purpose: Time-series aggregation for trend analysis
-- ============================================
IF OBJECT_ID('gold.vw_monthly_trends', 'V') IS NOT NULL
    DROP VIEW gold.vw_monthly_trends;
GO

CREATE VIEW gold.vw_monthly_trends AS
SELECT
    d.year,
    d.month,
    d.month_name,
    d.month_year_label,
    d.quarter_name,
    d.season,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.sales) AS total_sales,
    SUM(f.profit) AS total_profit,
    SUM(f.quantity) AS total_units,
    SUM(CAST(f.is_returned AS INT)) AS total_returns,
    SUM(f.sales) / NULLIF(COUNT(DISTINCT f.order_id), 0) AS avg_order_value
FROM gold.fact_sales f
JOIN gold.dim_date d ON f.order_date_key = d.date_key
GROUP BY d.year, d.month, d.month_name, d.month_year_label, d.quarter_name, d.season;
GO

PRINT 'All 6 gold layer views created successfully.';
GO