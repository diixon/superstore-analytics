# Architecture

This document explains how data moves through the SuperStore Analytics pipeline, why the project follows a Medallion (Bronze → Silver → Gold) architecture, and how the Gold layer is modeled as a star schema for Power BI.

---

## 1. Overview

The pipeline takes a single raw Excel file containing three tables (Orders, People, Returns) and progressively refines it into an analytics-ready data warehouse inside SQL Server. Each stage of refinement lives in its own schema:

```
Excel (raw_data.xlsx)
        │
        ▼
┌───────────────┐      ┌───────────────┐      ┌───────────────┐
│   BRONZE      │ ───▶ │   SILVER      │ ───▶ │    GOLD       │ ───▶ Power BI
│  Raw landing  │      │ Cleansed data │      │ Star schema   │
└───────────────┘      └───────────────┘      └───────────────┘
```

| Layer | Schema | Purpose |
|---|---|---|
| **Bronze** | `bronze` | Raw, untouched data exactly as imported from Excel |
| **Silver** | `silver` | Cleansed, validated, deduplicated data |
| **Gold** | `gold` | Business-ready star schema (dimensions + fact table) consumed by Power BI |

The Bronze layer can be populated either by an automated Python pipeline (`scripts/`, recommended — see §8) or manually via SSMS's Import Wizard; both feed into the same Silver and Gold stored procedures described below.

### Why Medallion architecture?

- **Traceability** — raw data is preserved untouched in Bronze, so any transformation can be audited or re-run without re-importing from Excel.
- **Separation of concerns** — data cleaning logic (Silver) is isolated from business modeling logic (Gold), making each stage easier to understand, test, and modify independently.
- **Reproducibility** — each layer is rebuilt by a single stored procedure, so the entire warehouse can be regenerated from scratch in a known order.

---

## 2. Bronze Layer — Raw Landing Zone

**Script:** `sql/01_bronze_layer.sql`
**Procedure:** `bronze.usp_CreateBronzeTables`

Three tables are created to receive data exactly as it exists in the source Excel file, with no cleaning or transformation applied:

| Table | Description | Approx. Rows |
|---|---|---|
| `bronze.orders` | Raw order-line transactions (sales, customer, product, shipping) | 9,994 |
| `bronze.people` | Sales person to region mapping | 5 |
| `bronze.returns_order` | Order IDs flagged as returned | 800 |

**How data gets here:** Data is loaded from `data/raw/raw_data.xlsx` into Bronze using one of two methods: the automated Python pipeline (`scripts/`, recommended — see §8 below), or manually via the SQL Server Import/Export Wizard (SSMS → *Tasks → Import Data*), running one query per sheet (`SELECT * FROM [Orders$]`, etc.) directly into the corresponding Bronze table. See `docs/setup_guide.md` for the exact steps for both options.

---

## 3. Silver Layer — Cleansed & Validated Data

**Script:** `sql/02_silver_layer.sql`
**Procedure:** `silver.usp_LoadSilverLayer`

This layer applies data-quality fixes and deduplication discovered while profiling the raw data. Every fix is scripted so it is reproducible and documented, rather than being a one-off manual correction:

| Table | Cleaning Applied |
|---|---|
| `silver.orders` | • Corrects one known bad `order_date` (order `CA-2016-153927`)<br>• Derives a valid `ship_mode` from shipping duration when the source value is invalid (`'null'`/`'0'`)<br>• Fixes an invalid `country_region` value (`'123'` → `United States`)<br>• Fills a missing `postal_code` for Burlington, VT<br>• Corrects one known bad `product_name` and collapses double spaces in others<br>• Casts `discount` to a consistent `DECIMAL(3,2)`<br>• Removes exact duplicate rows via `ROW_NUMBER()` |
| `silver.people` | Deduplicates by `person_name`, keeping one row per person |
| `silver.returns_order` | Deduplicates by `order_id`, keeping one row per order |

Each table also receives a `dw_load_date` column recording when the row was processed, which supports basic auditing of pipeline runs.

---

## 4. Gold Layer — Star Schema

**Script:** `sql/03_gold_layer.sql`
**Procedure:** `gold.usp_LoadGoldLayer(@DateRangeStart, @DateRangeEnd)`

The Gold layer restructures the cleansed Silver data into a **star schema**: a central fact table surrounded by descriptive dimension tables, connected by surrogate keys. This is the model Power BI connects to directly.

### 4.1 Star Schema Diagram

```
                        ┌────────────────────┐
                        │   gold.dim_date     │
                        │  date_key (PK)      │
                        └─────────┬───────────┘
                                  │ order_date_key
                                  │ ship_date_key (role-playing)
                                  │
┌──────────────────┐    ┌────────▼────────────┐    ┌──────────────────┐
│ gold.dim_customer │───▶│                     │◀───│ gold.dim_product │
│ customer_key (PK) │    │  gold.fact_sales    │    │ product_key (PK) │
└──────────────────┘    │  fact_key (PK)       │    └──────────────────┘
                        │  order_id            │
┌──────────────────┐    │  sales, profit,      │    ┌──────────────────────┐
│ gold.dim_location │───▶│  quantity, discount, │◀───│ gold.dim_ship_mode    │
│ location_key (PK) │    │  unit_price,         │    │ ship_mode_key (PK)    │
└──────────────────┘    │  profit_margin,      │    └──────────────────────┘
                        │  days_to_ship,        │
                        │  is_returned          │    ┌──────────────────────┐
                        └───────────┬───────────┘◀───│ gold.dim_sales_person │
                                    │                 │ sales_person_key (PK) │
                                    ▼                 └──────────────────────┘
                          (silver.returns_order,
                           joined by order_id
                           to derive is_returned)
```

### 4.2 Dimension Tables

| Table | Grain | Notes |
|---|---|---|
| `gold.dim_date` | One row per calendar date | Generated via recursive CTE across a configurable date range (default `2016-01-01` to `2020-12-31`). Includes year, quarter, month, week, weekday, weekend flag, business-day flag, and season — supports rich time-intelligence in Power BI without extra DAX. |
| `gold.dim_customer` | One row per `customer_id` | SCD Type 1 (overwrite on reload, no history tracked) |
| `gold.dim_product` | One row per `product_id` + `product_name` | SCD Type 1 |
| `gold.dim_location` | One row per `city` + `state` + `postal_code` | SCD Type 1 |
| `gold.dim_ship_mode` | One row per distinct ship mode | Small lookup dimension |
| `gold.dim_sales_person` | One row per sales person | Sourced from `silver.people`, linked to fact table via `region` |

### 4.3 Fact Table

**`gold.fact_sales`** — grain: one row per `order_id` + `product_id` (i.e., one row per order line item).

Built by joining `silver.orders` to every dimension table (via natural keys) to resolve surrogate keys, and left-joining `silver.returns_order` to derive the `is_returned` flag. Calculated columns (`unit_price`, `profit_margin`, `days_to_ship`) are computed once at load time rather than repeatedly in DAX.

**Role-playing date dimension:** `dim_date` is joined twice — once for `order_date_key` (active relationship) and once for `ship_date_key` (inactive relationship in Power BI, activated on demand via `USERELATIONSHIP()` in DAX where shipping-date analysis is needed).

**Data quality check:** the load procedure checks for fact rows with unmatched (`NULL`) dimension keys after the join and prints a warning — a lightweight safeguard against silent join failures.

---

## 5. Analytics Views

**Script:** `sql/04_views.sql`

Six views sit on top of the Gold star schema, pre-aggregating or pre-joining data for specific reporting needs. These exist so Power BI (and any other consumer) can query business-friendly, denormalized views rather than reconstructing joins/aggregations repeatedly:

| View | Purpose |
|---|---|
| `gold.vw_sales_summary` | Full row-level join across every dimension — the "flat table" for ad-hoc exploration |
| `gold.vw_product_performance` | Sales, profit, units, discount, and return metrics aggregated by product |
| `gold.vw_customer_analysis` | Spend, profit, order count, and return metrics aggregated by customer |
| `gold.vw_regional_performance` | Sales and shipping metrics aggregated by region/state/city and sales person |
| `gold.vw_shipping_performance` | Delivery time and return metrics aggregated by ship mode |
| `gold.vw_monthly_trends` | Time-series aggregation (orders, sales, profit, returns) by month/quarter/season |

---

## 6. Indexes

**Script:** `sql/05_indexes.sql`

Nonclustered indexes are added on five of the foreign-key columns in `gold.fact_sales` — `order_date_key`, `ship_date_key`, `customer_key`, `product_key`, and `location_key` — to speed up the joins performed by the views above and by Power BI's DirectQuery/import refresh, since the fact table is joined against every dimension. `ship_mode_key` and `sales_person_key` are left unindexed (both are small, low-cardinality dimensions).

---

## 7. From Gold Layer to Dashboard

Power BI Desktop connects to the `gold` schema (dimension tables + `gold.fact_sales`) and imports the star schema directly. Inside Power BI:

- Relationships mirror the surrogate-key joins shown in the diagram above (7 relationships total: 6 active, 1 inactive for the role-playing ship-date relationship).
- `gold.dim_date` is marked as the official **Date Table**.
- Surrogate keys (`*_key` columns) are hidden from report view — they exist only to support relationships.
- 13 DAX measures (e.g., `Total Sales`, `Profit Margin`, `CLV`, `Return Rate`, `On Time Delivery %`) are built on top of the fact table and consumed across the four report pages (Executive Summary, Product Analysis, Customer Insights, Operations).

---

## 8. Python Automation Layer

**Folder:** `scripts/`

The entire Excel → Bronze → Silver → Gold flow can be run with a single command (`python scripts/run_pipeline.py`) instead of the manual SSMS Import Wizard. This layer was built to remove the one part of the original pipeline that couldn't be expressed in pure T-SQL: getting data out of an Excel workbook and into SQL Server in the first place.

### 8.1 Design

| File | Responsibility |
|---|---|
| `db_utils.py` | A single shared `get_connection()` function (the SQL Server connection string) and the project's `logging` configuration. Every other script imports from here rather than duplicating connection details. |
| `load_people.py`, `load_orders.py`, `load_returns.py` | One function each, taking an open database `connection` as a parameter. Each reads its Excel sheet with `pandas`, renames columns to match the SQL schema, converts `NaN` (pandas' missing-value marker) to `None` (so SQL Server sees `NULL` instead of an invalid float), truncates the target Bronze table, and bulk-inserts the cleaned rows using `cursor.executemany()`. |
| `run_transformations.py` | Two functions, `run_silver_layer()` and `run_gold_layer()`, that simply `EXEC` the existing `silver.usp_LoadSilverLayer` and `gold.usp_LoadGoldLayer` stored procedures — the same procedures used by the manual path, so both paths are guaranteed to produce identical results. |
| `run_pipeline.py` | The master script. Opens one connection, calls each loader and transformation function in sequence, wrapping each call in its own `try/except` block so a failure in one step (e.g., Orders) doesn't prevent the others from being attempted, and closes the connection at the end. |
| `dev_notes/` | Exploratory scripts written while building this pipeline (initial data exploration, a standalone connection test, and a `try/except` practice example). Not part of the production pipeline — kept for reference. |

### 8.2 Why `executemany()` instead of row-by-row inserts

Early versions of the loaders inserted one row at a time via `cursor.execute()` in a loop — functionally correct, but slow: each call is a separate round-trip to SQL Server. For the ~10,000-row Orders table, this took roughly 20 seconds. Switching to `cursor.executemany()`, which batches all rows into far fewer round-trips, cut this to about 1.5 seconds — a ~13x improvement with no change in the actual data produced.

### 8.3 Error handling and logging

Rather than `print()` statements, the pipeline uses Python's built-in `logging` module, configured once in `db_utils.py` to write timestamped, leveled messages (`INFO` for normal progress, `ERROR` for failures) to `pipeline.log` in the project root. Combined with `try/except` around each pipeline step in `run_pipeline.py`, this means a failure in any single step is recorded clearly — which table, what the underlying SQL Server or Python error was — without stopping the rest of the pipeline or crashing with a raw traceback.

### 8.4 Idempotency

Every loader truncates its target Bronze table before inserting, and the Silver/Gold stored procedures drop and rebuild their own tables on every run. This means `python scripts/run_pipeline.py` can be re-run any number of times and always leaves the warehouse in the same state relative to whatever is currently in `data/raw/raw_data.xlsx` — running it once or ten times produces an identical result.

See `docs/data_dictionary.md` for full column-level definitions of every table, and `docs/setup_guide.md` for how to rebuild this pipeline end-to-end.