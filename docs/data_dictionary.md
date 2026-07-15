# 📖 Data Dictionary

This document describes the tables, columns, and business metrics used in the **SuperStore Sales Data Warehouse**.

---

# Fact Table

## `gold.fact_sales`

**Grain:** One record per **Order × Product** line item.

| Column | Data Type | Description |
|--------|-----------|-------------|
| `fact_key` | INT | Surrogate primary key. |
| `order_date_key` | INT | Foreign key to `dim_date` (order date). |
| `ship_date_key` | INT | Foreign key to `dim_date` (ship date). |
| `customer_key` | INT | Foreign key to `dim_customer`. |
| `product_key` | INT | Foreign key to `dim_product`. |
| `location_key` | INT | Foreign key to `dim_location`. |
| `ship_mode_key` | INT | Foreign key to `dim_ship_mode`. |
| `sales_person_key` | INT | Foreign key to `dim_sales_person`. |
| `order_id` | VARCHAR(50) | Degenerate dimension representing the transaction ID. |
| `sales` | DECIMAL(10,4) | Revenue generated from the line item. |
| `quantity` | INT | Number of units sold. |
| `discount` | DECIMAL(5,4) | Discount applied (0.00–0.80). |
| `profit` | DECIMAL(10,4) | Profit generated from the line item. |
| `unit_price` | DECIMAL(10,4) | Calculated as `sales / quantity`. |
| `profit_margin` | DECIMAL(10,4) | Calculated as `profit / sales`. |
| `days_to_ship` | INT | Number of days between order and shipment. |
| `is_returned` | BIT | Return indicator (`1` = Returned, `0` = Not Returned). |

---

# Dimension Tables

## `gold.dim_date`

| Column | Data Type | Description |
|--------|-----------|-------------|
| `date_key` | INT | Surrogate key in `YYYYMMDD` format. |
| `full_date` | DATE | Calendar date. |
| `year` | INT | Calendar year. |
| `quarter_name` | VARCHAR(10) | Quarter (`Q1`–`Q4`). |
| `month` | INT | Month number (1–12). |
| `month_name` | VARCHAR(10) | Full month name. |
| `month_short` | VARCHAR(3) | Month abbreviation. |
| `month_year_label` | VARCHAR(20) | Month-Year label (e.g., `Jan 2018`). |
| `week_of_year` | INT | ISO week number. |
| `day_of_month` | INT | Day of month (1–31). |
| `day_of_week` | INT | Day number (`1 = Sunday`, `7 = Saturday`). |
| `day_name` | VARCHAR(10) | Full weekday name. |
| `day_short` | VARCHAR(3) | Weekday abbreviation. |
| `is_weekend` | BIT | Weekend flag. |
| `is_business_day` | BIT | Business day flag (`Monday–Friday`). |
| `season` | VARCHAR(10) | Season (`Winter`, `Spring`, `Summer`, `Fall`). |

---

## `gold.dim_customer`

| Column | Data Type | Description |
|--------|-----------|-------------|
| `customer_key` | INT | Surrogate primary key. |
| `customer_id` | VARCHAR(50) | Business key from source system. |
| `customer_name` | VARCHAR(100) | Customer full name. |
| `segment` | VARCHAR(50) | Customer segment (`Consumer`, `Corporate`, `Home Office`). |

---

## `gold.dim_product`

| Column | Data Type | Description |
|--------|-----------|-------------|
| `product_key` | INT | Surrogate primary key. |
| `product_id` | VARCHAR(50) | Source product identifier. |
| `product_name` | VARCHAR(255) | Product name. |
| `category` | VARCHAR(50) | Product category. |
| `sub_category` | VARCHAR(50) | Product sub-category. |

> **Note:** `product_id` is **not unique** in the source dataset. The warehouse uses the combination of **(`product_id`, `product_name`)** to uniquely identify products before assigning surrogate keys.

---

## `gold.dim_location`

| Column | Data Type | Description |
|--------|-----------|-------------|
| `location_key` | INT | Surrogate primary key. |
| `city` | VARCHAR(100) | City name. |
| `state` | VARCHAR(50) | State name. |
| `postal_code` | VARCHAR(50) | ZIP / Postal code. |
| `region` | VARCHAR(50) | Sales region (`East`, `West`, `Central`, `South`). |

---

## `gold.dim_ship_mode`

| Column | Data Type | Description |
|--------|-----------|-------------|
| `ship_mode_key` | INT | Surrogate primary key. |
| `ship_mode` | VARCHAR(50) | Shipping method. |

**Possible values**

- First Class
- Second Class
- Standard Class
- Same Day

---

## `gold.dim_sales_person`

| Column | Data Type | Description |
|--------|-----------|-------------|
| `sales_person_key` | INT | Surrogate primary key. |
| `person_name` | VARCHAR(50) | Regional sales representative. |
| `region` | VARCHAR(50) | Assigned sales region. |

---

# Silver Layer Source Tables

These tables contain cleansed operational data used to populate the Gold layer.

---

## `silver.orders`

| Column | Data Type | Description |
|--------|-----------|-------------|
| `row_id` | INT | Unique source row identifier. |
| `order_id` | VARCHAR(50) | Order transaction ID. |
| `order_date` | DATE | Order creation date. |
| `ship_date` | DATE | Shipment date. |
| `ship_mode` | VARCHAR(50) | Shipping method. |
| `customer_id` | VARCHAR(50) | Customer identifier. |
| `customer_name` | VARCHAR(100) | Customer full name. |
| `segment` | VARCHAR(50) | Customer segment. |
| `country_region` | VARCHAR(50) | Country. |
| `city` | VARCHAR(100) | City. |
| `state` | VARCHAR(50) | State. |
| `postal_code` | VARCHAR(50) | Postal code. |
| `region` | VARCHAR(50) | Sales region. |
| `product_id` | VARCHAR(50) | Product identifier. |
| `category` | VARCHAR(50) | Product category. |
| `sub_category` | VARCHAR(50) | Product sub-category. |
| `product_name` | VARCHAR(255) | Product name. |
| `sales` | DECIMAL(10,4) | Sales amount. |
| `quantity` | INT | Units sold. |
| `discount` | DECIMAL(3,2) | Discount percentage. |
| `profit` | DECIMAL(10,4) | Profit amount. |

---

## `silver.people`

| Column | Data Type | Description |
|--------|-----------|-------------|
| `person_name` | VARCHAR(50) | Sales representative. |
| `region` | VARCHAR(50) | Assigned sales region. |

---

## `silver.returns_order`

| Column | Data Type | Description |
|--------|-----------|-------------|
| `returned` | VARCHAR(3) | Return flag (`Yes`). |
| `order_id` | VARCHAR(20) | Returned order identifier. |

---

# Business Metrics

| Metric | Formula |
|--------|---------|
| **Total Sales** | `SUM(sales)` |
| **Total Profit** | `SUM(profit)` |
| **Profit Margin (%)** | `SUM(profit) / SUM(sales) × 100` |
| **Total Orders** | `COUNT(DISTINCT order_id)` |
| **Average Order Value (AOV)** | `SUM(sales) / COUNT(DISTINCT order_id)` |
| **Return Rate (%)** | `Returned Orders / Total Orders × 100` |
| **Average Shipping Days** | `AVG(days_to_ship)` |

---

# Entity Relationship Summary

```text
                dim_date
                   ▲
          order_date_key
          ship_date_key
                   │
                   │
dim_customer ──────┤
dim_product ───────┤
dim_location ──────┤
dim_ship_mode ─────┤
dim_sales_person ──┤
                   ▼
             fact_sales
```

The `fact_sales` table is the central fact table in the star schema. Each record represents a single product sold within an order and links to all dimension tables through surrogate keys.