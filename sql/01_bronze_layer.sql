-- ============================================
-- Script:    01_bronze_layer.sql
-- Purpose:   Create bronze tables (raw data landing zone)
-- Project:   SuperStore Analytics
-- ============================================

USE SuperStoreProject;
GO
SET NOCOUNT ON;
GO

-- ============================================
-- Stored Procedure: bronze.usp_CreateBronzeTables
-- ============================================
IF OBJECT_ID('bronze.usp_CreateBronzeTables', 'P') IS NOT NULL
    DROP PROCEDURE bronze.usp_CreateBronzeTables;
GO

CREATE PROCEDURE bronze.usp_CreateBronzeTables
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        PRINT '=== Creating Bronze Layer Tables ===';

        -- ============================================
        -- Table: bronze.orders
        -- ============================================
        IF OBJECT_ID('bronze.orders', 'U') IS NOT NULL
            DROP TABLE bronze.orders;

        CREATE TABLE bronze.orders (
            row_id          INT,
            order_id        VARCHAR(50),
            order_date      DATE,
            ship_date       DATE,
            ship_mode       VARCHAR(50),
            customer_id     VARCHAR(50),
            customer_name   VARCHAR(100),
            segment         VARCHAR(50),
            country_region  VARCHAR(50),
            city            VARCHAR(100),
            state           VARCHAR(50),
            postal_code     VARCHAR(50),
            region          VARCHAR(50),
            product_id      VARCHAR(50),
            category        VARCHAR(50),
            sub_category    VARCHAR(50),
            product_name    VARCHAR(255),
            sales           DECIMAL(10,4),
            quantity        INT,
            discount        DECIMAL(5,4),
            profit          DECIMAL(10,4)
        );
        PRINT '[1/3] bronze.orders created.';

        -- ============================================
        -- Table: bronze.people
        -- ============================================
        IF OBJECT_ID('bronze.people', 'U') IS NOT NULL
            DROP TABLE bronze.people;

        CREATE TABLE bronze.people (
            person_name VARCHAR(50),
            region      VARCHAR(50)
        );
        PRINT '[2/3] bronze.people created.';

        -- ============================================
        -- Table: bronze.returns_order
        -- ============================================
        IF OBJECT_ID('bronze.returns_order', 'U') IS NOT NULL
            DROP TABLE bronze.returns_order;

        CREATE TABLE bronze.returns_order (
            returned    VARCHAR(3),
            order_id    VARCHAR(20)
        );
        PRINT '[3/3] bronze.returns_order created.';

        PRINT '=== Bronze Layer Tables Created Successfully ===';

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO

-- ============================================
-- Execute the procedure
-- ============================================
EXEC bronze.usp_CreateBronzeTables;
GO