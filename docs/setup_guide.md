# Setup Guide

This guide walks through rebuilding the entire SuperStore Analytics pipeline from scratch: creating the database, importing the raw data, running the SQL scripts in order, and connecting Power BI.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| **SQL Server** | Developer or Express edition, running locally. Tested via SQL Server Management Studio (SSMS). |
| **SQL Server Management Studio (SSMS)** | Used to run scripts and perform the Excel import. |
| **Power BI Desktop** | Used to open and explore `dashboard/superstoredashboard.pbix`. |
| **Windows Authentication** | Scripts and instructions assume a local instance using Windows Authentication (no SQL login/password setup required). |
| **Microsoft Access Database Engine (Excel import driver)** | Required by SSMS's Import/Export Wizard to read `.xlsx` files. If the Excel data source option isn't available in the wizard, install the [Microsoft Access Database Engine Redistributable](https://www.microsoft.com/en-us/download/details.aspx?id=54920) (64-bit, matching your SSMS/SQL Server bitness). |

---

## Step 1 — Run the SQL Scripts (in order)

Open each script in SSMS and execute it against your SQL Server instance, **in this exact order**:

```
sql/00_init_database.sql     → creates the SuperStoreProject database + bronze/silver/gold schemas
sql/01_bronze_layer.sql      → creates bronze.usp_CreateBronzeTables, then run it to create bronze tables
sql/02_silver_layer.sql      → creates silver.usp_LoadSilverLayer (do not run yet — needs bronze data first)
sql/03_gold_layer.sql        → creates gold.usp_LoadGoldLayer (do not run yet — needs silver data first)
sql/04_views.sql             → creates the 6 analytics views (needs gold tables to exist first)
sql/05_indexes.sql           → creates performance indexes on gold.fact_sales
```

**Important:** `00_init_database.sql` will **drop and recreate** the `SuperStoreProject` database if it already exists. Only run it if you intend to rebuild from scratch.

After running `00_init_database.sql` and `01_bronze_layer.sql`, you should have three empty tables ready to receive data: `bronze.orders`, `bronze.people`, `bronze.returns_order`. Don't run the Silver or Gold procedures yet — they depend on Bronze data existing first (Step 2 below).

---

## Step 2 — Import Raw Data into Bronze (Manual Step)

The raw data (`data/raw/raw_data.xlsx`) is loaded into the Bronze tables using SSMS's **Import/Export Wizard**, because the source is an Excel workbook rather than a SQL script. This step can't be expressed as pure T-SQL, so it must be repeated manually for each of the three sheets.

### 2.1 Launch the wizard
1. In SSMS Object Explorer, right-click the **SuperStoreProject** database.
2. Select **Tasks → Import Data...**

### 2.2 Choose the source
- **Data source:** Microsoft Excel
- **Excel file path:** browse to `data/raw/raw_data.xlsx`
- **Excel version:** Microsoft Excel 2007–2010 (or your installed version)
- Check **"First row has column names"**
- Click **Next >**

### 2.3 Choose the destination
- **Destination:** Microsoft OLE DB Provider for SQL Server (or SQL Server Native Client, depending on version)
- **Server name:** your local instance (e.g., `.`, `(local)`, or `localhost`)
- **Authentication:** Windows Authentication
- **Database:** `SuperStoreProject`
- Click **Next >**

### 2.4 Choose "Write a query" (critical step)
On the **"Specify Table Copy or Query"** screen, select:
> **"Write a query to specify the data to transfer"**

This avoids the wizard trying to auto-map all three sheets at once, which is a common source of import errors. Click **Next >**.

### 2.5 Repeat for each of the three sheets

Run the wizard **three separate times** — once per table — using the queries and destination mappings below:

| # | SQL Statement | Destination table |
|---|---|---|
| 1 | `SELECT * FROM [Orders$]` | `bronze.orders` |
| 2 | `SELECT * FROM [People$]` | `bronze.people` |
| 3 | `SELECT * FROM [Returns$]` | `bronze.returns_order` |

For each one:
1. Paste the query into the **SQL Statement** box → **Next >**
2. Check the box next to the source query, then set the **Destination** dropdown to the correct target table (see table above).
3. Click **Edit Mappings...** to verify columns line up correctly, then **OK**.
4. Click **Next >**, then **Finish** to run the transfer.
5. Before finishing, in the bottom-right corner set:
   - **On Error (global):** `Ignore`
   - **On Truncation (global):** `Ignore` *(optional, but safer for text fields with unexpected lengths)*

### 2.6 Verify the import

Run a quick row-count check in SSMS:

```sql
SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM bronze.orders
UNION ALL
SELECT 'people', COUNT(*) FROM bronze.people
UNION ALL
SELECT 'returns_order', COUNT(*) FROM bronze.returns_order;
```

Expected results: `orders` ≈ 9,994 rows, `people` = 5 rows, `returns_order` ≈ 800 rows.

---

## Step 3 — Load Silver and Gold Layers

Once Bronze data is confirmed, run the stored procedures created in Step 1, in order:

```sql
EXEC silver.usp_LoadSilverLayer;
GO

EXEC gold.usp_LoadGoldLayer;
GO
```

`gold.usp_LoadGoldLayer` accepts two optional date-range parameters (defaults shown below) that control how far `gold.dim_date` extends:

```sql
EXEC gold.usp_LoadGoldLayer
    @DateRangeStart = '2016-01-01',
    @DateRangeEnd   = '2020-12-31';
```

Watch the **Messages** tab in SSMS — each procedure prints progress for every table it loads (e.g., `[1/7] gold.dim_date loaded: ... rows.`), plus a warning if any fact rows end up with unmatched dimension keys.

---

## Step 4 — Create Views and Indexes

Run the remaining two scripts:

```
sql/04_views.sql      → creates the 6 analytics views under the gold schema
sql/05_indexes.sql    → creates 5 nonclustered indexes on gold.fact_sales
```

At this point the warehouse is fully built. You can sanity-check it with:

```sql
SELECT TOP 10 * FROM gold.vw_sales_summary;
```

---

## Step 5 — Open the Power BI Dashboard

1. Open `dashboard/superstoredashboard.pbix` in Power BI Desktop.
2. If the file was built against a different SQL Server instance name than yours, update the data source:
   **Home → Transform Data → Data source settings → Change Source...**, then point it at your local instance.
3. Click **Refresh** to pull current data from the `gold` schema tables.
4. The report opens on four pages: **Executive Summary**, **Product Analysis**, **Customer Insights**, and **Operations**.

### For reference, the data model behind the report:

- **7 relationships** between `gold_fact_sales` and the dimension tables:
  - 6 active (`product_key`, `customer_key`, `sales_person_key`, `location_key`, `ship_mode_key`, and `order_date_key` → `dim_date`)
  - 1 inactive (`ship_date_key` → `dim_date`, a role-playing relationship activated in specific DAX measures via `USERELATIONSHIP()` where shipping-date analysis is needed)
- `gold_dim_date` is marked as the official **Date Table** (on `full_date`)
- Surrogate keys and ETL-only columns (`fact_key`, `dw_load_date`, and all `*_key` foreign keys) are hidden in Model View — only business-friendly columns are visible to report users
- 13 DAX measures are defined on `gold_fact_sales` (see `docs/data_dictionary.md` for the full list)

If you'd rather rebuild the report from scratch instead of just opening the existing `.pbix`, the original build steps (page-by-page visual placement, measure DAX, and formatting) are preserved in the project's development notes and can be added to `docs/` on request.

---

## Troubleshooting

| Issue | Likely cause / fix |
|---|---|
| Excel data source not available in Import Wizard | Install the Microsoft Access Database Engine Redistributable (matching bitness of SQL Server/SSMS) |
| Import fails partway through | Set **On Error** and **On Truncation** to `Ignore` in the wizard's advanced settings (bottom-right corner) before finishing |
| `gold.usp_LoadGoldLayer` reports unmatched dimension keys | Usually means Bronze/Silver data wasn't fully loaded before running the Gold procedure — re-verify Step 2 row counts before proceeding |
| Power BI can't refresh / connection error | Check the data source server name matches your local instance name (Step 5.2) and that Windows Authentication is being used |
| Re-running `00_init_database.sql` | This drops and recreates the entire database — only intended for a full rebuild from scratch |

---

For details on what each layer/table/view actually contains, see [`architecture.md`](./architecture.md) and [`data_dictionary.md`](./data_dictionary.md).
