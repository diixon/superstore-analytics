-- ============================================
-- Script:    02_silver_layer.sql
-- Purpose:   Cleanse, validate, and deduplicate data from bronze to silver
-- Project:   SuperStore Analytics
-- ============================================

USE SuperStoreProject;
GO
SET NOCOUNT ON;
GO

-- ============================================
-- Stored Procedure: silver.usp_LoadSilverLayer
-- ============================================
IF OBJECT_ID('silver.usp_LoadSilverLayer', 'P') IS NOT NULL
    DROP PROCEDURE silver.usp_LoadSilverLayer;
GO

CREATE PROCEDURE silver.usp_LoadSilverLayer
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        PRINT '=== Starting Silver Layer Load ===';

        -- ============================================
        -- Table: silver.orders
        -- ============================================
        IF OBJECT_ID('silver.orders', 'U') IS NOT NULL
            DROP TABLE silver.orders;

        WITH cleaned_orders AS (
            SELECT
                row_id,
                order_id,

                -- Fix known bad order date
                CASE 
                    WHEN order_id = 'CA-2016-153927' THEN '2016-08-12'
                    ELSE order_date
                END AS order_date,

                ship_date,

                -- Fix invalid ship modes by deriving from ship duration
                CASE 
                    WHEN ship_mode IN ('null', '0') THEN
                        CASE 
                            WHEN DATEDIFF(DAY, order_date, ship_date) <= 1 THEN 'Same Day'
                            WHEN DATEDIFF(DAY, order_date, ship_date) BETWEEN 3 AND 7 THEN 'Standard Class'
                            ELSE 'Unknown'  -- ambiguous zone (2-5 days overlaps First/Second Class)
                        END
                    ELSE ship_mode
                END AS ship_mode,

                customer_id,
                customer_name,
                segment,

                -- Fix invalid country
                CASE 
                    WHEN country_region = '123' THEN 'United States'
                    ELSE country_region
                END AS country_region,

                city,
                state,

                -- Fix missing postal code for Burlington, VT
                CASE 
                    WHEN city = 'Burlington' AND state = 'Vermont' THEN '05401'
                    ELSE postal_code
                END AS postal_code,

                region,
                product_id,
                category,
                sub_category,

                -- Fix known bad product name + remove double spaces
                CASE 
                    WHEN product_id = 'OFF-AP-10002684' 
                        THEN 'Acco 7-Outlet Masterpiece Power Center, Wihtout Fax/Phone Line Protection'
                    ELSE REPLACE(product_name, '  ', ' ')
                END AS product_name,

                sales,
                quantity,
                CAST(discount AS DECIMAL(3,2)) AS discount,
                profit,

                -- Deduplication: flag exact duplicate rows
                ROW_NUMBER() OVER (
                    PARTITION BY 
                        order_id, order_date, ship_date, ship_mode,
                        customer_id, customer_name, segment, country_region,
                        city, state, postal_code, region, product_id,
                        category, sub_category, product_name,
                        sales, quantity, discount, profit
                    ORDER BY row_id
                ) AS rn
            FROM bronze.orders
        )
        SELECT
            row_id, order_id, order_date, ship_date, ship_mode,
            customer_id, customer_name, segment, country_region,
            city, state, postal_code, region, product_id,
            category, sub_category, product_name,
            sales, quantity, discount, profit,
            GETDATE() AS dw_load_date
        INTO silver.orders
        FROM cleaned_orders
        WHERE rn = 1;

        PRINT '[1/3] silver.orders loaded: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows.';

        -- ============================================
        -- Table: silver.people
        -- ============================================
        IF OBJECT_ID('silver.people', 'U') IS NOT NULL
            DROP TABLE silver.people;

        SELECT
            person_name,
            region,
            GETDATE() AS dw_load_date
        INTO silver.people
        FROM (
            SELECT 
                person_name, 
                region,
                ROW_NUMBER() OVER (PARTITION BY person_name ORDER BY region) AS row_num
            FROM bronze.people
        ) AS cleaned_data
        WHERE row_num = 1;

        PRINT '[2/3] silver.people loaded: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows.';

        -- ============================================
        -- Table: silver.returns_order
        -- ============================================
        IF OBJECT_ID('silver.returns_order', 'U') IS NOT NULL
            DROP TABLE silver.returns_order;

        SELECT
            returned,
            order_id,
            GETDATE() AS dw_load_date
        INTO silver.returns_order
        FROM (
            SELECT 
                returned, 
                order_id,
                ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY returned) AS row_num
            FROM bronze.returns_order
        ) AS cleaned_data
        WHERE row_num = 1;

        PRINT '[3/3] silver.returns_order loaded: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows.';

        PRINT '=== Silver Layer Load Complete ===';

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
EXEC silver.usp_LoadSilverLayer;
GO