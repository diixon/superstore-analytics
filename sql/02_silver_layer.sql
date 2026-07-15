IF OBJECT_ID('silver.orders', 'U') IS NOT NULL
    DROP TABLE silver.orders;
GO

WITH cleaned_orders AS (
    SELECT
        row_id,
        order_id,

        CASE WHEN order_id = 'CA-2016-153927' THEN '2016-08-12'
             ELSE order_date
        END AS order_date,

        ship_date,

        -- ship_mode: bucket known bad values instead of passing them through
        CASE WHEN ship_mode IN ('null', '0')
             THEN CASE WHEN DATEDIFF(day, order_date, ship_date) <= 1 THEN 'Same Day'
                       WHEN DATEDIFF(day, order_date, ship_date) BETWEEN 3 AND 7 THEN 'Standard Class'
                       ELSE 'Unknown' -- ambiguous zone (2-5 days overlaps First/Second)
                  END
             ELSE ship_mode
        END AS ship_mode,

        customer_id,
        customer_name,
        segment,

        CASE WHEN country_region = '123' THEN 'United States'
             ELSE country_region
        END AS country_region,

        city,
        state,

        CASE WHEN city = 'Burlington' AND state = 'Vermont' THEN '05401'
             ELSE postal_code
        END AS postal_code,

        region,
        product_id,
        category,
        sub_category,

        CASE WHEN product_id = 'OFF-AP-10002684'
             THEN 'Acco 7-Outlet Masterpiece Power Center, Wihtout Fax/Phone Line Protection'
             ELSE REPLACE(product_name, '  ', ' ')
        END AS product_name,

        sales,
        quantity,
        CAST(discount AS DECIMAL(3,2)) AS discount,
        profit,

        -- Deduplication: Remove exact duplicates (all columns match)
        ROW_NUMBER() OVER (
            PARTITION BY 
                order_id,
                order_date,
                ship_date,
                ship_mode,
                customer_id,
                customer_name,
                segment,
                country_region,
                city,
                state,
                postal_code,
                region,
                product_id,
                category,
                sub_category,
                product_name,
                sales,
                quantity,
                discount,
                profit
            ORDER BY row_id
        ) AS rn
    FROM bronze.orders
)
SELECT
    row_id,
    order_id,
    order_date,
    ship_date,
    ship_mode,
    customer_id,
    customer_name,
    segment,
    country_region,
    city,
    state,
    postal_code,
    region,
    product_id,
    category,
    sub_category,
    product_name,
    sales,
    quantity,
    discount,
    profit,
    GETDATE() AS dw_load_date
INTO silver.orders
FROM cleaned_orders
WHERE rn = 1;  -- Keep only the first occurrence of exact duplicates
GO

IF OBJECT_ID('silver.people', 'U') IS NOT NULL
    DROP TABLE silver.people;
GO

SELECT
    person_name,
    region,
    GETDATE() AS dwh_load_date
INTO silver.people
FROM (
    -- Cleanse: Remove duplicates by keeping the first occurrence per person
    SELECT 
        person_name, 
        region,
        ROW_NUMBER() OVER (PARTITION BY person_name ORDER BY region) AS row_num
    FROM bronze.people
) AS cleaned_data
WHERE row_num = 1;
GO

IF OBJECT_ID('silver.returns_order', 'U') IS NOT NULL
    DROP TABLE silver.returns_order;
GO

SELECT
    returned,
    order_id,
    GETDATE() AS dwh_load_date
INTO silver.returns_order
FROM (
    SELECT 
        returned, 
        order_id,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY returned) AS row_num
    FROM bronze.returns_order
) AS cleaned_data
WHERE row_num = 1;  -- Keep only the first occurrence per order_id
GO