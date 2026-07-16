-- ============================================
-- Script:    05_indexes.sql
-- Purpose:   Nonclustered indexes on gold.fact_sales for query performance
-- Project:   SuperStore Analytics
-- ============================================

USE SuperStoreProject;
GO
SET NOCOUNT ON;
GO

-- ============================================
-- Fact table indexes
-- Supports common filter/join patterns used by the gold views
-- and Power BI dashboard (date filters, dimension joins)
-- ============================================

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_fact_sales_order_date' AND object_id = OBJECT_ID('gold.fact_sales')
)
    CREATE NONCLUSTERED INDEX IX_fact_sales_order_date ON gold.fact_sales(order_date_key);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_fact_sales_ship_date' AND object_id = OBJECT_ID('gold.fact_sales')
)
    CREATE NONCLUSTERED INDEX IX_fact_sales_ship_date ON gold.fact_sales(ship_date_key);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_fact_sales_customer' AND object_id = OBJECT_ID('gold.fact_sales')
)
    CREATE NONCLUSTERED INDEX IX_fact_sales_customer ON gold.fact_sales(customer_key);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_fact_sales_product' AND object_id = OBJECT_ID('gold.fact_sales')
)
    CREATE NONCLUSTERED INDEX IX_fact_sales_product ON gold.fact_sales(product_key);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'IX_fact_sales_location' AND object_id = OBJECT_ID('gold.fact_sales')
)
    CREATE NONCLUSTERED INDEX IX_fact_sales_location ON gold.fact_sales(location_key);
GO

PRINT 'Fact table indexes created successfully.';
GO