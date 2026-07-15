# 🏪 SuperStore Sales Data Warehouse

An end-to-end data engineering project built with **SQL Server** and **Power BI**, following the **Medallion Architecture** (Bronze → Silver → Gold).

![SQL Server](https://img.shields.io/badge/SQL%20Server-CC2927?style=flat&logo=microsoft-sql-server&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=power-bi&logoColor=black)
![HTML](https://img.shields.io/badge/HTML5-E34F26?style=flat&logo=html5&logoColor=white)
![Git](https://img.shields.io/badge/Git-F05032?style=flat&logo=git&logoColor=white)

---

## 📊 Project Overview

This project transforms raw SuperStore sales data (2016–2019) into a fully modeled **star schema data warehouse**, complete with an interactive dashboard.

| Metric | Value |
|--------|------:|
| Total Sales | $2.3M |
| Total Orders | 5,006 |
| Products | 1,894 |
| Customers | 793 |
| Line Items | 9,993 |

---

## 🏗️ Architecture

```text
┌──────────────────────────────────────────────┐
│                BRONZE LAYER                  │
│           Raw data imported as-is            │
│                                              │
│  • bronze.orders                            │
│  • bronze.people                            │
│  • bronze.returns_order                     │
└───────────────────┬──────────────────────────┘
                    │
          Cleanse • Validate • Standardize
                    ▼
┌──────────────────────────────────────────────┐
│                SILVER LAYER                  │
│     Cleaned, deduplicated, validated data    │
│                                              │
│  • silver.orders                            │
│  • silver.people                            │
│  • silver.returns_order                     │
└───────────────────┬──────────────────────────┘
                    │
            Star Schema Modeling
                    ▼
┌──────────────────────────────────────────────┐
│                 GOLD LAYER                   │
│         Analytics-ready dimensional model    │
│                                              │
│  • dim_date (1,827 rows)                    │
│  • dim_customer (793 rows)                  │
│  • dim_product (1,894 rows)                 │
│  • dim_location (632 rows)                  │
│  • dim_ship_mode (4 rows)                   │
│  • dim_sales_person (4 rows)                │
│  • fact_sales (9,993 rows)                  │
│  • 6 Analytics Views                        │
└──────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```text
super_store_prjct/
│
├── README.md                      # Project documentation
├── .gitignore                     # Files excluded from Git
│
├── data/
│   └── raw_data.xlsx              # Original SuperStore dataset
│
├── sql/
│   ├── 00_init_database.sql       # Create database & schemas
│   ├── 01_bronze_layer.sql        # Raw data import
│   ├── 02_silver_layer.sql        # Data cleansing & validation
│   ├── 03_gold_layer.sql          # Star schema (dimensions & fact)
│   ├── 04_views.sql               # Analytics views
│   └── 05_indexes.sql             # Performance indexes
│
├── dashboard/
│   ├── superstore_dashboard.html  # Interactive HTML dashboard
│   └── superstore_dashboard.pbix  # Power BI report
│
└── docs/
    └── documentation files
```

---

## ⭐ Star Schema Design

### Dimension Tables

| Table | Rows | Description |
|-------|-----:|-------------|
| `dim_date` | 1,827 | Calendar lookup (2016–2020) |
| `dim_customer` | 793 | Customer information |
| `dim_product` | 1,894 | Product catalog (composite key) |
| `dim_location` | 632 | City, state, postal code, region |
| `dim_ship_mode` | 4 | Shipping methods |
| `dim_sales_person` | 4 | Regional sales representatives |

### Fact Table

| Table | Rows | Grain |
|-------|-----:|-------|
| `fact_sales` | 9,993 | One row per `order_id` + `product_id` |

### Analytics Views

| View | Purpose |
|------|---------|
| `vw_sales_summary` | Complete star schema join |
| `vw_product_performance` | Product performance analysis |
| `vw_customer_analysis` | Customer segmentation |
| `vw_regional_performance` | Regional sales analysis |
| `vw_shipping_performance` | Shipping performance metrics |
| `vw_monthly_trends` | Monthly sales trends |

---

## 🔧 Key Technical Decisions

| Decision | Implementation |
|----------|----------------|
| Duplicate products | Composite key (`product_id` + `product_name`) |
| Duplicate rows | Removed exact duplicates in the Silver layer |
| Invalid `ship_mode` values | Standardized into valid shipping categories |
| Returns | Stored as `is_returned` (`BIT`) in the fact table |
| Date dimension | Pre-generated with calendar attributes for BI |
| Slowly Changing Dimensions | Type 1 (overwrite), suitable for static dataset |

---

## 📈 Dashboard Features

- 📌 KPI Cards (Sales, Profit, Orders, Average Order Value, Return Rate)
- 📅 Monthly Sales Trend (2016–2019)
- 🌎 Regional Performance Analysis
- 📦 Category & Sub-category Breakdown
- 🚚 Shipping Performance
- 🏆 Top Products by Sales & Profit
- 👥 Top Customers
- 📱 Responsive HTML dashboard and Power BI report

---

## 🚀 Getting Started

### Prerequisites

- SQL Server 2019+
- SQL Server Management Studio (SSMS)
- Power BI Desktop (optional)

### Installation

#### 1. Clone the repository

```bash
git clone https://github.com/diixon/super_store_prjct.git
cd super_store_prjct
```

#### 2. Execute SQL scripts in order

```text
00_init_database.sql
01_bronze_layer.sql
02_silver_layer.sql
03_gold_layer.sql
04_views.sql
05_indexes.sql
```

#### 3. Open the dashboards

**HTML Dashboard**

```text
dashboard/superstore_dashboard.html
```

**Power BI Report**

```text
dashboard/superstore_dashboard.pbix
```

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| Database | Microsoft SQL Server |
| ETL | T-SQL |
| Data Warehouse | Medallion Architecture |
| Data Modeling | Kimball Star Schema |
| Visualization | Power BI & Chart.js |
| Version Control | Git & GitHub |

---

## 📝 License

This project was created for **educational** and **portfolio** purposes.

---

## 👤 Author

**Mohamed**

- GitHub: **[@diixon](https://github.com/diixon)**

---

## ⭐ If you found this project useful, consider giving it a star!