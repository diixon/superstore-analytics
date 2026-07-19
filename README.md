# SuperStore Analytics

An end-to-end data analytics project built on a single retail sales dataset — from raw Excel data, through a SQL Server data warehouse built with a **Medallion (Bronze → Silver → Gold) architecture**, into a **4-page Power BI dashboard**. The full pipeline — Excel → Bronze → Silver → Gold — can be run with a single Python command, no manual data import required.

This project was built as a hands-on exercise in data warehouse design, T-SQL development, dimensional modeling, Python automation/ETL, and BI dashboard design.

---

## 📖 Overview

Retail sales data (orders, sales reps, and returns) starts as a single Excel workbook and flows through three progressively refined layers in SQL Server before landing in a Power BI report:

```
Excel (raw_data.xlsx)
        │
        ▼ (automated via scripts/run_pipeline.py)
   BRONZE  →  SILVER  →  GOLD  →  Power BI Dashboard
  (raw data) (cleansed) (star schema)
```

- **Bronze** — raw data landed exactly as imported, no transformation
- **Silver** — cleansed, validated, and deduplicated data with documented data-quality fixes
- **Gold** — a star schema (6 dimensions + 1 fact table) built for reporting, plus 6 analytics views
- **Power BI** — a 4-page interactive dashboard with 13 DAX measures, connected directly to the Gold layer
- **Python pipeline** — a set of scripts (`scripts/`) that automate the entire Excel → Bronze → Silver → Gold flow, with error handling and logging, replacing manual data entry

Full technical detail on each stage lives in [`docs/architecture.md`](docs/architecture.md).

---

## 📑 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Technologies Used](#️-technologies-used)
- [Project Structure](#-project-structure)
- [Dashboard Preview](#️-dashboard-preview)
- [Installation](#-installation)
- [Database Setup](#️-database-setup)
- [Usage](#-usage)
- [Configuration](#️-configuration)
- [Deployment](#-deployment)
- [Future Improvements](#-future-improvements)
- [Contribution Guidelines](#-contribution-guidelines)
- [License](#-license)
- [About the Author](#-about-the-author)

---

## ✨ Features

- **Medallion architecture** implemented with stored procedures for each layer (`bronze.usp_CreateBronzeTables`, `silver.usp_LoadSilverLayer`, `gold.usp_LoadGoldLayer`)
- **Documented data-quality fixes** — bad dates, invalid ship modes, invalid country codes, missing postal codes, malformed product names, and exact-duplicate removal, all handled in scripted, reproducible SQL rather than manual edits
- **Star schema** with surrogate keys, a role-playing date dimension (order date vs. ship date), and a generated date dimension with fiscal/seasonal attributes
- **6 analytics views** for product, customer, regional, shipping, and monthly-trend reporting
- **Performance indexes** on fact-table foreign keys
- **4-page Power BI dashboard** — Executive Summary, Product Analysis, Customer Insights, and Operations — with 13 custom DAX measures (Total Sales, Profit Margin, CLV, Return Rate, On Time Delivery %, and more)
- **Python automation pipeline** (`pandas` + `pyodbc`) that reads the raw Excel file and loads it into SQL Server, then triggers the Silver and Gold transformations — a single command (`python scripts/run_pipeline.py`) rebuilds the entire warehouse, with error handling and persistent logging (`pipeline.log`) instead of the manual SSMS Import Wizard

---

## 🛠️ Technologies Used

| Category | Technology |
|---|---|
| Database | SQL Server (T-SQL, stored procedures, views, indexes) |
| Source data | Microsoft Excel (3-sheet workbook: Orders, People, Returns) |
| Automation / ETL | Python (`pandas`, `openpyxl`, `pyodbc`), virtual environments, `logging` |
| Data import (manual alternative) | SQL Server Import/Export Wizard (SSMS) |
| BI / Visualization | Power BI Desktop, DAX |
| Architecture pattern | Medallion (Bronze / Silver / Gold), Star Schema (Kimball-style dimensional modeling) |

---

## 📁 Project Structure

```
superstore-analytics/
│
├── README.md                     ← you are here
├── LICENSE
├── .gitignore
├── requirements.txt               ← pinned Python dependencies
│
├── data/
│   └── raw/
│       └── raw_data.xlsx         ← source workbook (Orders, People, Returns sheets)
│
├── sql/
│   ├── 00_init_database.sql      ← creates database + bronze/silver/gold schemas
│   ├── 01_bronze_layer.sql       ← raw landing tables
│   ├── 02_silver_layer.sql       ← cleansing & deduplication
│   ├── 03_gold_layer.sql         ← star schema (dimensions + fact table)
│   ├── 04_views.sql              ← 6 analytics views
│   └── 05_indexes.sql            ← performance indexes
│
├── scripts/                       ← Python automation pipeline
│   ├── db_utils.py                ← shared SQL Server connection + logging config
│   ├── load_people.py             ← loads bronze.people from Excel
│   ├── load_orders.py             ← loads bronze.orders from Excel
│   ├── load_returns.py            ← loads bronze.returns_order from Excel
│   ├── run_transformations.py     ← runs the Silver and Gold stored procedures
│   ├── run_pipeline.py            ← master script: Excel → Bronze → Silver → Gold, one command
│   └── dev_notes/                 ← exploratory scripts from development (not part of the pipeline)
│
├── dashboard/
│   └── superstoredashboard.pbix  ← Power BI report (4 pages)
│
└── docs/
    ├── architecture.md           ← pipeline design & star schema explained
    ├── data_dictionary.md        ← every table/column/view/measure defined
    ├── setup_guide.md            ← step-by-step reproduction guide
    └── screenshots/               ← dashboard page images
```

---

## 🖼️ Dashboard Preview

### Executive Summary
![Executive Summary](docs/screenshots/dashboard_executive.PNG)

### Product Analysis
![Product Analysis](docs/screenshots/dashboard_products.PNG)

### Customer Insights
![Customer Insights](docs/screenshots/dashboard_customers.PNG)

### Operations
![Operations](docs/screenshots/dashboard_operations.PNG)

---

## 🚀 Installation

### Prerequisites
- SQL Server (Developer or Express edition), running locally with Windows Authentication
- SQL Server Management Studio (SSMS)
- Power BI Desktop
- Python 3.10+ (for the automated pipeline) — with ODBC Driver 18 for SQL Server installed
- Microsoft Access Database Engine Redistributable — only needed if using the **manual** import wizard alternative — [download here](https://www.microsoft.com/en-us/download/details.aspx?id=54920)

### Quick start
```bash
git clone https://github.com/<your-username>/superstore-analytics.git
cd superstore-analytics
```

Then follow the full step-by-step walkthrough in [`docs/setup_guide.md`](docs/setup_guide.md), which covers two ways to load the data:

**Option A — Automated (recommended):**
```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python scripts/run_pipeline.py
```
This runs the SQL scripts' setup, then loads Bronze from Excel, then triggers Silver and Gold — end to end, one command.

**Option B — Manual:**
1. Running the SQL scripts in order
2. Importing `data/raw/raw_data.xlsx` into the Bronze layer via SSMS's Import Wizard
3. Loading the Silver and Gold layers manually via `EXEC`

Either way, finish by opening the Power BI report and refreshing the connection.

---

## 🗄️ Database Setup

**Automated (recommended):** after running `sql/00_init_database.sql` and `sql/01_bronze_layer.sql` once to create the schema, everything else is handled by:
```bash
python scripts/run_pipeline.py
```
This loads Bronze from Excel, then runs the Silver and Gold stored procedures — no manual data entry.

**Manual alternative:** the database can also be rebuilt by running six scripts **in order** and importing data via the SSMS wizard in between:

| Step | Script | What it does |
|---|---|---|
| 1 | `00_init_database.sql` | Creates the `SuperStoreProject` database and `bronze`/`silver`/`gold` schemas |
| 2 | `01_bronze_layer.sql` | Creates raw landing tables |
| — | *(manual)* | Import `data/raw/raw_data.xlsx` into Bronze tables via SSMS Import Wizard |
| 3 | `02_silver_layer.sql` | Cleanses and deduplicates data into the Silver layer |
| 4 | `03_gold_layer.sql` | Builds the Gold star schema (dimensions + fact table) |
| 5 | `04_views.sql` | Creates 6 analytics views |
| 6 | `05_indexes.sql` | Adds performance indexes on the fact table |

⚠️ `00_init_database.sql` drops and recreates the database if it already exists — only run it for a full rebuild.

See [`docs/setup_guide.md`](docs/setup_guide.md) for the complete walkthrough of both options, including troubleshooting tips.

---

## 📊 Usage

Once the database is built and populated:

- Query the Gold-layer views directly for ad-hoc analysis, e.g.:
  ```sql
  SELECT * FROM gold.vw_monthly_trends ORDER BY year, month;
  ```
- Open `dashboard/superstoredashboard.pbix` in Power BI Desktop to explore the interactive report across its 4 pages: **Executive Summary**, **Product Analysis**, **Customer Insights**, and **Operations**.
- Refresh the Power BI data source if your SQL Server instance name differs from the one the report was originally built against (see `docs/setup_guide.md`, Step 5).

*(See [Dashboard Preview](#dashboard-preview) above for screenshots of all 4 pages.)*

---

## ⚙️ Configuration

There's no application config file in this project — the only environment-specific setting is the **SQL Server instance name**, which is referenced in three places:

1. **`scripts/db_utils.py`** — the `get_connection()` function's connection string (`Server=localhost;` by default) — update if your instance name differs
2. **SSMS Import Wizard** (manual alternative) — set to your local instance when importing the Excel data
3. **Power BI data source** — update via *Home → Transform Data → Data source settings* if it doesn't match your instance

The Gold layer's date range is configurable via parameters on `gold.usp_LoadGoldLayer`:
```sql
EXEC gold.usp_LoadGoldLayer
    @DateRangeStart = '2016-01-01',
    @DateRangeEnd   = '2020-12-31';
```

---

## 📦 Deployment

This project is designed to run on a **local SQL Server instance** for learning/portfolio purposes and isn't currently packaged for cloud deployment. If you want to adapt it:

- **Azure SQL Database** — the T-SQL is largely compatible. The Python pipeline (`scripts/`) would need its connection string updated to point at Azure SQL instead of `localhost`, and `pyodbc` would need Azure SQL's stricter TLS/auth settings — much simpler than adapting the old manual Import Wizard, which couldn't reach a cloud database at all.
- **Power BI Service** — publish the `.pbix` file and set up a scheduled refresh with a gateway if the database moves off your local machine.

These aren't implemented in this repo yet — see **Future Improvements** below.

---

## 🔭 Future Improvements

- [ ] Build a lightweight HTML/web dashboard as a Power-BI-free alternative for viewing results in a browser
- [ ] Extend the Python pipeline to call the Silver/Gold procedures with configurable date-range parameters instead of hardcoded defaults
- [ ] Add a lightweight CI check (e.g., SQL linting, or running the Python pipeline against a test database) if the project moves to a shared/team setting
- [ ] Explore Azure SQL + Power BI Service deployment for a fully cloud-hosted version
- [ ] Add row-level data validation tests (e.g., using tSQLt or a simple assertion script) to catch data-quality regressions automatically

---

## 🤝 Contribution Guidelines

This is currently a personal learning project, but suggestions and feedback are welcome:

1. Open an issue describing the suggestion or bug
2. Fork the repo and create a feature branch
3. Submit a pull request with a clear description of the change

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

*Note: `data/raw/raw_data.xlsx` is a variant of the widely-used "Sample Superstore" dataset, commonly used for BI/analytics learning and demos. It is included here for educational/portfolio purposes.*

---

## 👤 About the Author

**Mohamed Ahmed**

- GitHub: [@diixon](https://github.com/diixon)
- LinkedIn: [mohamed-ahmed-421b9541b](https://www.linkedin.com/in/mohamed-ahmed-421b9541b)
- Email: [mmoohamedahmed1@gmail.com](mailto:mmoohamedahmed1@gmail.com)

This project was built as a hands-on exercise in data warehouse design, SQL Server development, and Power BI dashboarding — feel free to reach out with questions or feedback.