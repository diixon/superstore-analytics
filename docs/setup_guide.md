# Setup Guide

This guide walks through rebuilding the entire SuperStore Analytics pipeline from scratch: creating the database, loading the raw data, running the SQL scripts, and connecting Power BI. There are two ways to load the data — an **automated Python pipeline** (recommended) or the **manual SSMS Import Wizard**. Both are documented below.

---

## Prerequisites

| Requirement | Notes |
|---|---|
| **SQL Server** | Developer or Express edition, running locally. Tested via SQL Server Management Studio (SSMS). |
| **SQL Server Management Studio (SSMS)** | Used to run the SQL scripts, and for the manual import option. |
| **Power BI Desktop** | Used to open and explore `dashboard/superstoredashboard.pbix`. |
| **Windows Authentication** | Scripts and instructions assume a local instance using Windows Authentication (no SQL login/password setup required). |
| **Python 3.10+** | Required for the automated pipeline (`scripts/`). Includes `pip` for installing dependencies. |
| **ODBC Driver 18 for SQL Server** | Required by `pyodbc` (the Python-to-SQL Server connector) for the automated pipeline. Usually already present if SSMS is installed — check via PowerShell: `Get-OdbcDriver \| Where-Object {$_.Name -like "*SQL Server*"}`. |
| **Microsoft Access Database Engine (Excel import driver)** | Only needed for the **manual** import option. Required by SSMS's Import/Export Wizard to read `.xlsx` files. If missing, install the [Microsoft Access Database Engine Redistributable](https://www.microsoft.com/en-us/download/details.aspx?id=54920) (64-bit, matching your SSMS/SQL Server bitness). |

---

## Step 1 — Run the SQL Scripts (in order)

Open each script in SSMS and execute it against your SQL Server instance, **in this exact order**:

```
sql/00_init_database.sql     → creates the SuperStoreProject database + bronze/silver/gold schemas
sql/01_bronze_layer.sql      → creates bronze.usp_CreateBronzeTables, then run it to create bronze tables
sql/02_silver_layer.sql      → creates silver.usp_LoadSilverLayer (also executes it once — harmless with 0 rows if Bronze is still empty)
sql/03_gold_layer.sql        → creates gold.usp_LoadGoldLayer (also executes it once — harmless with 0 rows if Silver is still empty)
sql/04_views.sql             → creates the 6 analytics views
sql/05_indexes.sql           → creates performance indexes on gold.fact_sales
```

**Important:** `00_init_database.sql` will **drop and recreate** the `SuperStoreProject` database if it already exists. Only run it if you intend to rebuild from scratch.

Running all six scripts in order sets up the complete schema — tables, stored procedures, views, and indexes — even before any real data is loaded. The Silver and Gold procedures will simply process 0 rows the first time, which is expected. Once you load real data (Step 2 below), you'll re-run these same procedures to populate them properly.

---

## Step 2 — Load the Data: Automated or Manual

You now have two options to get `data/raw/raw_data.xlsx` into the Bronze tables and flow it through Silver and Gold. **Option A (automated) is recommended** — it's faster, repeatable, and doesn't require repeating GUI steps every time you want to reload data.

### Option A — Automated (recommended)

This uses the Python pipeline in `scripts/` to load Bronze from Excel, then trigger the Silver and Gold stored procedures — all in one command.

**2A.1 Set up a virtual environment** (a self-contained, isolated copy of Python's package system just for this project):
```bash
cd superstore-analytics
python -m venv venv
```

**2A.2 Activate it:**
```bash
venv\Scripts\activate
```
Your terminal prompt should now show `(venv)` at the start. You'll need to activate this every time you open a new terminal to work on this project.

**2A.3 Install dependencies:**
```bash
pip install -r requirements.txt
```
This installs `pandas`, `openpyxl`, `pyodbc`, and their dependencies at the exact versions this project was built and tested with.

**2A.4 Check the connection settings:**
Open `scripts/db_utils.py` and confirm the `Server=` value in `get_connection()` matches your SQL Server instance name (defaults to `localhost`).

**2A.5 Run the full pipeline:**
```bash
python scripts/run_pipeline.py
```

**What this does, step by step:**
1. Connects to `SuperStoreProject`
2. Reads each Excel sheet with `pandas`, cleans up missing values, and loads it into the matching Bronze table (truncating first, so re-running is always safe)
3. Calls `EXEC silver.usp_LoadSilverLayer` and `EXEC gold.usp_LoadGoldLayer` to rebuild Silver and Gold with the newly loaded data
4. Logs every step — successes and any errors — to `pipeline.log` in the project root, with timestamps

**What output to expect:**
The terminal stays fairly quiet (you may see a harmless `openpyxl` warning about worksheet headers/footers — safe to ignore). Check `pipeline.log` afterward:
```bash
type pipeline.log
```
You should see a sequence like:
```
INFO - bronze.people table truncated
INFO - Inserted 5 rows into bronze.people
INFO - bronze.orders table truncated
INFO - inserted 9994 rows into bronze.orders
INFO - bronze.returns_order table truncated
INFO - inserted 800 rows into bronze.returns_order
INFO - Silver layer procedure executed successfully.
INFO - Gold layer procedure executed successfully.
```

**Re-running the pipeline:** it's fully repeatable — running it again truncates and reloads every table fresh, so it always leaves the database in a consistent state matching the current Excel file.

Skip ahead to **Step 5 — Open the Power BI Dashboard** below. (Steps 3 and 4 describe the manual alternative and are already handled by the pipeline.)

---

### Option B — Manual (SSMS Import Wizard)

If you'd rather not use Python, or want to understand exactly what the automated pipeline does under the hood, follow this instead.

### B.1 Launch the wizard
1. In SSMS Object Explorer, right-click the **SuperStoreProject** database.
2. Select **Tasks → Import Data...**

### B.2 Choose the source
- **Data source:** Microsoft Excel
- **Excel file path:** browse to `data/raw/raw_data.xlsx`
- **Excel version:** Microsoft Excel 2007–2010 (or your installed version)
- Check **"First row has column names"**
- Click **Next >**

### B.3 Choose the destination
- **Destination:** Microsoft OLE DB Provider for SQL Server (or SQL Server Native Client, depending on version)
- **Server name:** your local instance (e.g., `.`, `(local)`, or `localhost`)
- **Authentication:** Windows Authentication
- **Database:** `SuperStoreProject`
- Click **Next >**

### B.4 Choose "Write a query" (critical step)
On the **"Specify Table Copy or Query"** screen, select:
> **"Write a query to specify the data to transfer"**

This avoids the wizard trying to auto-map all three sheets at once, which is a common source of import errors. Click **Next >**.

### B.5 Repeat for each of the three sheets

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

### B.6 Verify the import

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

## Step 3 — Load Silver and Gold Layers (manual path only)

*(If you used Option A above, this already happened automatically — skip to Step 5.)*

Once Bronze data is confirmed, re-run the stored procedures created in Step 1, in order:

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

## Step 4 — Views and Indexes (already created in Step 1)

If you ran all six scripts in Step 1, the 6 analytics views and 5 performance indexes already exist — nothing further to do here. You can sanity-check the warehouse with:

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
| `ModuleNotFoundError: No module named 'pandas'` (or similar) | The virtual environment isn't activated — run `venv\Scripts\activate` and confirm `(venv)` shows in your prompt before running any `python` command |
| `Could not find stored procedure 'silver.usp_LoadSilverLayer'` | The stored procedures don't exist yet — make sure you ran all of Step 1's SQL scripts (they both create and define the procedures) before running the Python pipeline |
| `pyodbc.connect` fails / "Attempt to use a closed connection" | Usually transient (SQL Server was momentarily busy). Simply re-run `python scripts/run_pipeline.py` — it's fully safe to re-run from scratch |
| Excel data source not available in Import Wizard (manual option only) | Install the Microsoft Access Database Engine Redistributable (matching bitness of SQL Server/SSMS) |
| Import fails partway through (manual option only) | Set **On Error** and **On Truncation** to `Ignore` in the wizard's advanced settings (bottom-right corner) before finishing |
| `gold.usp_LoadGoldLayer` reports unmatched dimension keys | Usually means Bronze/Silver data wasn't fully loaded before running the Gold procedure — re-verify row counts before proceeding |
| Power BI can't refresh / connection error | Check the data source server name matches your local instance name (Step 5.2) and that Windows Authentication is being used |
| Re-running `00_init_database.sql` | This drops and recreates the entire database — only intended for a full rebuild from scratch |

---

For details on what each layer/table/view actually contains, see [`architecture.md`](./architecture.md) and [`data_dictionary.md`](./data_dictionary.md).