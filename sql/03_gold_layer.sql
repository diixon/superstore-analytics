USE SuperStoreProject;
GO

IF OBJECT_ID('gold.dim_date', 'U') IS NOT NULL
    DROP TABLE gold.dim_date;
GO

CREATE TABLE gold.dim_date (
    date_key            INT PRIMARY KEY,
    full_date           DATE NOT NULL,
    year                INT,
    quarter_name        VARCHAR(10),
    month               INT,
    month_name          VARCHAR(10),
    month_short         VARCHAR(3),
    month_year_label    VARCHAR(20),
    week_of_year        INT,
    day_of_month        INT,
    day_of_week         INT,
    day_name            VARCHAR(10),
    day_short           VARCHAR(3),
    is_weekend          BIT,
    is_business_day     BIT,
    season              VARCHAR(10)
);
GO

DECLARE @start_date DATE = '2016-01-01';
DECLARE @end_date   DATE = '2020-12-31';


WITH date_series AS (
    SELECT @start_date AS full_date
    UNION ALL
    SELECT DATEADD(DAY, 1, full_date)
    FROM date_series
    WHERE full_date < @end_date
)
INSERT INTO gold.dim_date (
    date_key,
    full_date,
    year,
    quarter_name,
    month,
    month_name,
    month_short,
    month_year_label,
    week_of_year,
    day_of_month,
    day_of_week,
    day_name,
    day_short,
    is_weekend,
    is_business_day,
    season
)
SELECT
    CAST(CONVERT(VARCHAR(8), full_date, 112) AS INT) AS date_key,
    full_date,
    YEAR(full_date) AS year,
    'Q' + CAST(DATEPART(QUARTER, full_date) AS VARCHAR) AS quarter_name,
    MONTH(full_date) AS month,
    DATENAME(MONTH, full_date) AS month_name,
    LEFT(DATENAME(MONTH, full_date), 3) AS month_short,
    LEFT(DATENAME(MONTH, full_date), 3) + ' ' + CAST(YEAR(full_date) AS VARCHAR) AS month_year_label,
    DATEPART(ISO_WEEK, full_date) AS week_of_year,
    DAY(full_date) AS day_of_month,
    DATEPART(WEEKDAY, full_date) AS day_of_week,
    DATENAME(WEEKDAY, full_date) AS day_name,
    LEFT(DATENAME(WEEKDAY, full_date), 3) AS day_short,
    CASE WHEN DATEPART(WEEKDAY, full_date) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend,
    CASE WHEN DATEPART(WEEKDAY, full_date) IN (1, 7) THEN 0 ELSE 1 END AS is_business_day,
    CASE 
        WHEN MONTH(full_date) IN (12, 1, 2) THEN 'Winter'
        WHEN MONTH(full_date) IN (3, 4, 5)  THEN 'Spring'
        WHEN MONTH(full_date) IN (6, 7, 8)  THEN 'Summer'
        WHEN MONTH(full_date) IN (9, 10, 11) THEN 'Fall'
    END AS season
FROM date_series
OPTION (MAXRECURSION 0);
GO

IF OBJECT_ID('gold.dim_customer', 'U') IS NOT NULL
    DROP TABLE gold.dim_customer;
GO

CREATE TABLE gold.dim_customer (
    customer_key    INT IDENTITY(1,1) PRIMARY KEY,
    customer_id     VARCHAR(50) NOT NULL,
    customer_name   VARCHAR(100),
    segment         VARCHAR(50)
);
GO
INSERT INTO gold.dim_customer (customer_id, customer_name, segment)
SELECT DISTINCT
    customer_id,
    customer_name,
    segment
FROM silver.orders
ORDER BY customer_id;
GO

-- ============================================
-- GOLD LAYER: Dim_Product
-- ============================================
-- Grain: One row per unique product_id + product_name combination
-- SCD Type: 1 (Overwrite)

IF OBJECT_ID('gold.dim_product', 'U') IS NOT NULL
    DROP TABLE gold.dim_product;
GO

CREATE TABLE gold.dim_product (
    product_key     INT IDENTITY(1,1) PRIMARY KEY,
    product_id      VARCHAR(50) NOT NULL,
    product_name    VARCHAR(255) NOT NULL,
    category        VARCHAR(50),
    sub_category    VARCHAR(50)
);
GO

-- Populate Dim_Product
INSERT INTO gold.dim_product (product_id, product_name, category, sub_category)
SELECT DISTINCT
    product_id,
    product_name,
    category,
    sub_category
FROM silver.orders
ORDER BY product_id, product_name;
GO
-- ============================================
-- GOLD LAYER: Dim_Location
-- ============================================
-- Grain: One row per unique city + state + postal_code
-- SCD Type: 1 (Overwrite)

IF OBJECT_ID('gold.dim_location', 'U') IS NOT NULL
    DROP TABLE gold.dim_location;
GO

CREATE TABLE gold.dim_location (
    location_key    INT IDENTITY(1,1) PRIMARY KEY,
    city            VARCHAR(100),
    state           VARCHAR(50),
    postal_code     VARCHAR(50),
    region          VARCHAR(50)
);
GO

-- Populate Dim_Location
INSERT INTO gold.dim_location (city, state, postal_code, region)
SELECT DISTINCT
    city,
    state,
    postal_code,
    region
FROM silver.orders
ORDER BY city, state, postal_code;
GO
-- ============================================
-- GOLD LAYER: Dim_Ship_Mode
-- ============================================
-- Grain: One row per unique ship_mode

IF OBJECT_ID('gold.dim_ship_mode', 'U') IS NOT NULL
    DROP TABLE gold.dim_ship_mode;
GO

CREATE TABLE gold.dim_ship_mode (
    ship_mode_key   INT IDENTITY(1,1) PRIMARY KEY,
    ship_mode       VARCHAR(50) NOT NULL
);
GO

-- Populate Dim_Ship_Mode
INSERT INTO gold.dim_ship_mode (ship_mode)
SELECT DISTINCT ship_mode
FROM silver.orders
WHERE ship_mode IS NOT NULL
ORDER BY ship_mode;
GO
-- ============================================
-- GOLD LAYER: Dim_Sales_Person
-- ============================================
-- Grain: One row per sales person (region)

IF OBJECT_ID('gold.dim_sales_person', 'U') IS NOT NULL
    DROP TABLE gold.dim_sales_person;
GO

CREATE TABLE gold.dim_sales_person (
    sales_person_key    INT IDENTITY(1,1) PRIMARY KEY,
    person_name         VARCHAR(50),
    region              VARCHAR(50)
);
GO

-- Populate Dim_Sales_Person
INSERT INTO gold.dim_sales_person (person_name, region)
SELECT
    person_name,
    region
FROM silver.people
ORDER BY person_name;
GO
-- ============================================
-- GOLD LAYER: Fact_Sales
-- ============================================
-- Grain: One row per order_id + product_id

IF OBJECT_ID('gold.fact_sales', 'U') IS NOT NULL
    DROP TABLE gold.fact_sales;
GO

CREATE TABLE gold.fact_sales (
    fact_key            INT IDENTITY(1,1) PRIMARY KEY,
    order_date_key      INT NOT NULL,
    ship_date_key       INT,
    customer_key        INT NOT NULL,
    product_key         INT NOT NULL,
    location_key        INT NOT NULL,
    ship_mode_key       INT,
    sales_person_key    INT,
    order_id            VARCHAR(50) NOT NULL,
    sales               DECIMAL(10,4),
    quantity            INT,
    discount            DECIMAL(5,4),
    profit              DECIMAL(10,4),
    unit_price          DECIMAL(10,4),
    profit_margin       DECIMAL(10,4),
    days_to_ship        INT,
    is_returned         BIT
);
GO

-- Populate Fact_Sales
INSERT INTO gold.fact_sales (
    order_date_key,
    ship_date_key,
    customer_key,
    product_key,
    location_key,
    ship_mode_key,
    sales_person_key,
    order_id,
    sales,
    quantity,
    discount,
    profit,
    unit_price,
    profit_margin,
    days_to_ship,
    is_returned
)
SELECT
    od.date_key AS order_date_key,
    sd.date_key AS ship_date_key,
    c.customer_key,
    p.product_key,
    l.location_key,
    sm.ship_mode_key,
    sp.sales_person_key,
    o.order_id,
    o.sales,
    o.quantity,
    o.discount,
    o.profit,
    o.sales / NULLIF(o.quantity, 0) AS unit_price,
    o.profit / NULLIF(o.sales, 0) AS profit_margin,
    DATEDIFF(DAY, o.order_date, o.ship_date) AS days_to_ship,
    CASE WHEN r.order_id IS NOT NULL THEN 1 ELSE 0 END AS is_returned
FROM silver.orders o
LEFT JOIN gold.dim_date od ON od.full_date = o.order_date
LEFT JOIN gold.dim_date sd ON sd.full_date = o.ship_date
LEFT JOIN gold.dim_customer c ON c.customer_id = o.customer_id
LEFT JOIN gold.dim_product p ON p.product_id = o.product_id AND p.product_name = o.product_name
LEFT JOIN gold.dim_location l ON l.city = o.city AND l.state = o.state AND l.postal_code = o.postal_code
LEFT JOIN gold.dim_ship_mode sm ON sm.ship_mode = o.ship_mode
LEFT JOIN gold.dim_sales_person sp ON sp.region = o.region
LEFT JOIN silver.returns_order r ON r.order_id = o.order_id;
GO
