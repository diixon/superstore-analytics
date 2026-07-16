# Data Dictionary

This document defines every table and column across the Bronze, Silver, and Gold schemas. It's meant to be a reference for anyone reading or auditing the SQL scripts, and for understanding exactly what each field in the Power BI model represents.

For an explanation of *why* the schemas are structured this way, see [`architecture.md`](./architecture.md).

---

## Schema: `bronze`

Raw data, unmodified from the source Excel file. No constraints, no cleaning.

### `bronze.orders`

| Column | Type | Description |
|---|---|---|
| `row_id` | INT | Row number from the source file |
| `order_id` | VARCHAR(50) | Order identifier (repeats across line items in the same order) |
| `order_date` | DATE | Date the order was placed |
| `ship_date` | DATE | Date the order was shipped |
| `ship_mode` | VARCHAR(50) | Shipping method (may contain invalid values such as `'null'` or `'0'`) |
| `customer_id` | VARCHAR(50) | Customer identifier |
| `customer_name` | VARCHAR(100) | Customer full name |
| `segment` | VARCHAR(50) | Customer segment (e.g., Consumer, Corporate, Home Office) |
| `country_region` | VARCHAR(50) | Country/region (may contain invalid values such as `'123'`) |
| `city` | VARCHAR(100) | Shipping city |
| `state` | VARCHAR(50) | Shipping state |
| `postal_code` | VARCHAR(50) | Shipping postal code (may be missing for some rows) |
| `region` | VARCHAR(50) | Sales region (e.g., East, West, Central, South) |
| `product_id` | VARCHAR(50) | Product identifier |
| `category` | VARCHAR(50) | Product category |
| `sub_category` | VARCHAR(50) | Product sub-category |
| `product_name` | VARCHAR(255) | Product name (may contain formatting issues, e.g. double spaces) |
| `sales` | DECIMAL(10,4) | Line-item sales amount |
| `quantity` | INT | Units sold |
| `discount` | DECIMAL(5,4) | Discount applied (fraction, e.g. 0.20 = 20%) |
| `profit` | DECIMAL(10,4) | Line-item profit |

### `bronze.people`

| Column | Type | Description |
|---|---|---|
| `person_name` | VARCHAR(50) | Sales person name |
| `region` | VARCHAR(50) | Region the sales person is responsible for |

### `bronze.returns_order`

| Column | Type | Description |
|---|---|---|
| `returned` | VARCHAR(3) | Flag value indicating a return (e.g., `Yes`) |
| `order_id` | VARCHAR(20) | Order identifier that was returned |

---

## Schema: `silver`

Cleansed, validated, and deduplicated versions of the Bronze tables. Loaded by `silver.usp_LoadSilverLayer`.

### `silver.orders`

Same columns as `bronze.orders`, plus:

| Column | Type | Description |
|---|---|---|
| `dw_load_date` | DATETIME | Timestamp when this row was processed into the Silver layer |

**Cleaning applied** (see `architecture.md` §3 for full detail):
- One known bad `order_date` corrected (order `CA-2016-153927`)
- Invalid `ship_mode` values derived from shipping duration
- Invalid `country_region` value `'123'` corrected to `United States`
- Missing `postal_code` filled for Burlington, VT
- One known bad `product_name` corrected; double spaces collapsed in others
- `discount` cast to `DECIMAL(3,2)` for consistency
- Exact duplicate rows removed (kept lowest `row_id` per duplicate group)

### `silver.people`

| Column | Type | Description |
|---|---|---|
| `person_name` | VARCHAR(50) | Sales person name |
| `region` | VARCHAR(50) | Region the sales person is responsible for |
| `dw_load_date` | DATETIME | Timestamp when this row was processed |

Deduplicated by `person_name` (one row per person retained).

### `silver.returns_order`

| Column | Type | Description |
|---|---|---|
| `returned` | VARCHAR(3) | Flag value indicating a return |
| `order_id` | VARCHAR(20) | Order identifier that was returned |
| `dw_load_date` | DATETIME | Timestamp when this row was processed |

Deduplicated by `order_id` (one row per order retained).

---

## Schema: `gold`

Business-ready star schema. Loaded by `gold.usp_LoadGoldLayer`. This is the schema Power BI connects to.

### `gold.dim_date`
Grain: one row per calendar date.

| Column | Type | Description |
|---|---|---|
| `date_key` | INT (PK) | Surrogate key in `YYYYMMDD` format |
| `full_date` | DATE | The calendar date |
| `year` | INT | Calendar year |
| `quarter_name` | VARCHAR(10) | e.g. `Q1`, `Q2` |
| `month` | INT | Month number (1–12) |
| `month_name` | VARCHAR(10) | Full month name |
| `month_short` | VARCHAR(3) | Three-letter month abbreviation |
| `month_year_label` | VARCHAR(20) | e.g. `Jan 2019` — used for chart axis labels |
| `week_of_year` | INT | ISO week number |
| `day_of_month` | INT | Day number within the month |
| `day_of_week` | INT | Day number within the week |
| `day_name` | VARCHAR(10) | Full weekday name |
| `day_short` | VARCHAR(3) | Three-letter weekday abbreviation |
| `is_weekend` | BIT | 1 if Saturday/Sunday |
| `is_business_day` | BIT | 1 if Monday–Friday |
| `season` | VARCHAR(10) | Winter/Spring/Summer/Fall |

Generated for a configurable range (default `2016-01-01` to `2020-12-31`) via a recursive CTE.

### `gold.dim_customer`
Grain: one row per `customer_id`. SCD Type 1 (overwritten on each reload).

| Column | Type | Description |
|---|---|---|
| `customer_key` | INT IDENTITY (PK) | Surrogate key |
| `customer_id` | VARCHAR(50) | Natural key from source data |
| `customer_name` | VARCHAR(100) | Customer name |
| `segment` | VARCHAR(50) | Customer segment |

### `gold.dim_product`
Grain: one row per `product_id` + `product_name`. SCD Type 1.

| Column | Type | Description |
|---|---|---|
| `product_key` | INT IDENTITY (PK) | Surrogate key |
| `product_id` | VARCHAR(50) | Natural key from source data |
| `product_name` | VARCHAR(255) | Product name |
| `category` | VARCHAR(50) | Product category |
| `sub_category` | VARCHAR(50) | Product sub-category |

### `gold.dim_location`
Grain: one row per `city` + `state` + `postal_code`. SCD Type 1.

| Column | Type | Description |
|---|---|---|
| `location_key` | INT IDENTITY (PK) | Surrogate key |
| `city` | VARCHAR(100) | City |
| `state` | VARCHAR(50) | State |
| `postal_code` | VARCHAR(50) | Postal code |
| `region` | VARCHAR(50) | Sales region |

### `gold.dim_ship_mode`
Grain: one row per distinct shipping method.

| Column | Type | Description |
|---|---|---|
| `ship_mode_key` | INT IDENTITY (PK) | Surrogate key |
| `ship_mode` | VARCHAR(50) | Shipping method name (e.g., Standard Class, Same Day) |

### `gold.dim_sales_person`
Grain: one row per sales person.

| Column | Type | Description |
|---|---|---|
| `sales_person_key` | INT IDENTITY (PK) | Surrogate key |
| `person_name` | VARCHAR(50) | Sales person name |
| `region` | VARCHAR(50) | Region they are responsible for |

### `gold.fact_sales`
Grain: one row per `order_id` + `product_id` (one order line item).

| Column | Type | Description |
|---|---|---|
| `fact_key` | INT IDENTITY (PK) | Surrogate key for the fact row |
| `order_date_key` | INT (FK → `dim_date`) | Order date, active relationship |
| `ship_date_key` | INT (FK → `dim_date`) | Ship date, inactive relationship (role-playing dimension) |
| `customer_key` | INT (FK → `dim_customer`) | Customer reference |
| `product_key` | INT (FK → `dim_product`) | Product reference |
| `location_key` | INT (FK → `dim_location`) | Location reference |
| `ship_mode_key` | INT (FK → `dim_ship_mode`) | Shipping method reference |
| `sales_person_key` | INT (FK → `dim_sales_person`) | Sales person reference (joined via region) |
| `order_id` | VARCHAR(50) | Natural order identifier |
| `sales` | DECIMAL(10,4) | Line-item sales amount |
| `quantity` | INT | Units sold |
| `discount` | DECIMAL(5,4) | Discount applied |
| `profit` | DECIMAL(10,4) | Line-item profit |
| `unit_price` | DECIMAL(10,4) | Calculated: `sales / quantity` |
| `profit_margin` | DECIMAL(10,4) | Calculated: `profit / sales` |
| `days_to_ship` | INT | Calculated: `ship_date - order_date` |
| `is_returned` | BIT | 1 if `order_id` appears in `silver.returns_order`, else 0 |

---

## Analytics Views (`gold` schema)

These views aggregate or flatten `gold.fact_sales` for specific reporting needs. See `architecture.md` §5 for their purpose; column definitions below.

### `gold.vw_sales_summary`
Row-level grain (one row per fact row). Combines every dimension attribute with fact measures: `full_date`, `year`, `quarter_name`, `month_name`, `month_year_label`, `day_name`, `is_weekend`, `is_business_day`, `season`, `customer_id`, `customer_name`, `segment`, `product_id`, `product_name`, `category`, `sub_category`, `city`, `state`, `region`, `ship_mode`, `sales_person`, `order_id`, `sales`, `quantity`, `discount`, `profit`, `unit_price`, `profit_margin`, `days_to_ship`, `is_returned`.

### `gold.vw_product_performance`
Grain: one row per product. Columns: `product_id`, `product_name`, `category`, `sub_category`, `total_orders`, `total_sales`, `total_profit`, `total_units`, `avg_discount`, `avg_unit_price`, `profit_margin_pct`, `total_returns`.

### `gold.vw_customer_analysis`
Grain: one row per customer. Columns: `customer_id`, `customer_name`, `segment`, `total_orders`, `total_spent`, `total_profit`, `avg_order_value`, `total_units`, `total_returns`.

### `gold.vw_regional_performance`
Grain: one row per region/state/city/sales person combination. Columns: `region`, `state`, `city`, `sales_person`, `total_orders`, `total_sales`, `total_profit`, `total_units`, `avg_shipping_days`, `total_returns`.

### `gold.vw_shipping_performance`
Grain: one row per ship mode. Columns: `ship_mode`, `total_orders`, `avg_days_to_ship`, `min_days`, `max_days`, `total_sales`, `total_returns`.

### `gold.vw_monthly_trends`
Grain: one row per year/month. Columns: `year`, `month`, `month_name`, `month_year_label`, `quarter_name`, `season`, `total_orders`, `total_sales`, `total_profit`, `total_units`, `total_returns`, `avg_order_value`.

---

## Power BI DAX Measures

Defined on `gold_fact_sales` in the Power BI model (not in SQL — these live inside the `.pbix` file).

| Measure | Description |
|---|---|
| `Total Sales` | Sum of sales amount |
| `Total Profit` | Sum of profit |
| `Profit Margin` | Total Profit ÷ Total Sales |
| `Total Orders` | Distinct count of order IDs |
| `Total Customers` | Distinct count of customers |
| `Total Returned` | Count of returned orders |
| `CLV` | Customer Lifetime Value (average profit per customer, extrapolated) |
| `Return Rate` | Total Returned ÷ Total Orders |
| `Average Order Value` | Total Sales ÷ Total Orders |
| `Average Unit Price` | Average of `unit_price` |
| `Average Shipping Days` | Average of `days_to_ship` |
| `Total Quantity` | Sum of quantity sold |
| `Average Discount` | Average of `discount` |
| `On Time Delivery %` | Share of orders with `days_to_ship <= 5` |
| `Total Returned Orders` | Sum of `is_returned` flag |

---

## Indexes (`sql/05_indexes.sql`)

Nonclustered indexes are created on five foreign-key columns of `gold.fact_sales` — `order_date_key`, `ship_date_key`, `customer_key`, `product_key`, and `location_key` (index names: `IX_fact_sales_order_date`, `IX_fact_sales_ship_date`, `IX_fact_sales_customer`, `IX_fact_sales_product`, `IX_fact_sales_location`) — to support the joins used by the views above and by Power BI's data refresh. `ship_mode_key` and `sales_person_key` are not indexed.
