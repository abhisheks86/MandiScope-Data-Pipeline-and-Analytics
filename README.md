# 🌾 MandiScope-Data-Pipeline-and-Analytics

##  What Is This Project?

**MandiScope** is a production-grade, end-to-end data engineering pipeline that transforms 811,131 rows of raw, messy Indian government agricultural price data into an interactive executive intelligence dashboard.

The pipeline connects three major technologies — **Python, MySQL, and Power BI** — into a seamless automated flow using the industry-standard **Medallion Architecture (Bronze → Silver → Gold)**.

> **Business Problem:** Indian agricultural markets suffer from severe price inconsistencies across states and seasons. Procurement teams and logistics managers have no reliable way to identify arbitrage opportunities, track commodity inflation, or time bulk purchases efficiently.
>
> **Solution:** MandiScope processes 4 years of daily mandi price data across 32 Indian states and delivers actionable market intelligence through advanced SQL analytics and a 3-page executive Power BI dashboard.

---

##  Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    RAW DATA SOURCE                       │
│         Government Mandi Price Records 2023–2026         │
│                    811,131 rows                          │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              🥉 BRONZE LAYER — Python/Pandas             │
│  • Partition raw data by year (2023, 2024, 2025, 2026)  │
│  • Preserve original data — no cleaning at this stage   │
│  • Handle schema drift between reporting years           │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              🥈 SILVER LAYER — Python/Pandas             │
│  • Remove 538,843 null rows                             │
│  • Drop 5,115 duplicate records                         │
│  • Fix mixed date formats (US/Indian)                   │
│  • Standardise STATE text (118 → 30 unique values)      │
│  • Enforce price logic (Max > Min)                      │
│  • Output: 266,139 clean rows                           │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│           🥇 GOLD LAYER — MySQL Star Schema              │
│  • Load via SQLAlchemy engine                           │
│  • Build UNION ALL View across all 4 years              │
│  • Generate MD5 surrogate keys                          │
│  • Create 3 Dimension Tables + 1 Fact Table             │
│  • 213,856 fact records ready for analytics             │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│           📊 ANALYTICS — Advanced SQL                    │
│  • 4 business queries (CTE, LAG, RANK, CASE WHEN)      │
│  • Arbitrage, Inflation, Volatility, Seasonality        │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│           📈 DASHBOARD — Power BI                        │
│  • 3-page interactive executive dashboard               │
│  • Star Schema data model with relationships            │
│  • Market Overview · Price Intelligence · Risk          │
└─────────────────────────────────────────────────────────┘
```

---

##  Dashboard Preview

| Page | Title | Key Visuals |
|---|---|---|
| Page 1 | Market Overview | Price trend line chart, India map, donut chart, state heat map |
| Page 2 | Price Intelligence | Arbitrage table, inflation tracker, volatility index, seasonality heat map |
| Page 3 | Risk & Volatility | Scatter plot, price spread analysis, star schema visuals |

---

##  Star Schema Design

```
          ┌──────────────────┐
          │   dim_date       │
          │  date_id (PK)    │
          │  full_date       │
          │  sales_year      │
          │  sales_month     │
          └────────┬─────────┘
                   │ 1
                   │
┌──────────────┐   │        ┌──────────────────┐
│ dim_location │   │        │  dim_commodity   │
│ location_id  │   │        │  commodity_id    │
│ state        │ 1─┤─*      │  commodity_name  │
│ district     │   │        │  variety         │
│ market       │   │        │  grade           │
└──────┬───────┘   │        └────────┬─────────┘
       │ 1         │                 │ 1
       │           ▼                 │
       │  ┌─────────────────────┐    │
       └──│  fact_mandi_prices  │────┘
          │  price_id (PK)      │
          │  location_id (FK)   │
          │  commodity_id (FK)  │
          │  date_id (FK)       │
          │  Min_Price          │
          │  Max_Price          │
          │  Modal_Price        │
          │  Price_Spread       │
          └─────────────────────┘
```

**Key Engineering Decision:** Used `MD5(CONCAT(...))` to generate deterministic surrogate keys — ensuring perfect referential integrity and making the pipeline fully repeatable without auto-increment dependencies.

---

## Business Intelligence Queries

### Query 1 — The Arbitrage Finder
```sql
-- Finds same-day price gaps > ₹500 for the same commodity in the same state
-- Technique: CTE + HAVING filter
-- Business value: Exposes immediate logistics routing opportunities
```
**Finding:** Maximum arbitrage spread of **₹79,750** found for Onion in Kerala (2023)

---

### Query 2 — The Inflation Tracker
```sql
-- Tracks Month-over-Month price change for essential crops
-- Technique: CTE + LAG() Window Function
-- Business value: Identifies inflation spikes before they hit supply chains
```
**Finding:** Tomato price spiked **+146% MoM** — flagging supply disruption

---

### Query 3 — The Volatility Risk Index
```sql
-- Calculates price spread as % of modal price per commodity per year
-- Technique: Mathematical aggregation + HAVING filter
-- Business value: Ranks commodities by supply chain risk level
```
**Finding:** Onion most volatile at **25.23%** in 2023 — highest risk commodity

---

### Query 4 — The Seasonality Analyzer
```sql
-- Ranks months 1-12 historically from cheapest to most expensive
-- Technique: CTE + RANK() Window Function + CASE WHEN labels
-- Business value: Guides bulk procurement timing decisions
```
**Finding:** May is cheapest month for Onion (₹2,081 avg) — optimal bulk buy window

---

## Data Quality Results

| Problem Found | Raw Count | After Cleaning |
|---|---|---|
| Total raw rows | 811,131 | — |
| Null rows (systematic) | 538,843 | 0 ✅ |
| Duplicate records | 5,115 | 0 ✅ |
| Zero / negative prices | ~1,000 | 0 ✅ |
| Mixed case STATE names | 118 unique | 30 unique ✅ |
| Min Price > Max Price | ~88 rows | 0 ✅ |
| Mixed date formats | All rows | Standardised ✅ |
| **Final clean rows** | — | **266,139** |

---

## 📂 Repository Structure

```
MandiScope-Data-Pipeline/
│
├── 📁 data/
│   ├── bronze/                    ← Raw partitioned files by year
│   │   ├── Raw_Mandi_Unclean_2023.csv
│   │   ├── Raw_Mandi_Unclean_2024.csv
│   │   ├── Raw_Mandi_Unclean_2025.csv
│   │   └── Raw_Mandi_Unclean_NO_DATE.csv
│   ├── silver/                    ← Cleaned files by year
│   │   ├── Clean_Mandi_2023.csv
│   │   ├── Clean_Mandi_2024.csv
│   │   ├── Clean_Mandi_2025.csv
│   │   └── Clean_Mandi_2026.csv
│   └── gold/                      ← Star Schema tables
│       ├── fact_mandi_prices.csv
│       ├── dim_location.csv
│       ├── dim_date.csv
│       └── dim_commodity.csv
│
├── 📁 notebooks/                  ← Python ETL pipeline
│   ├── 01_bronze_partition.py
│   ├── 02_etl_cleaning_2023.py
│   ├── 03_etl_cleaning_2024.py
│   ├── 04_etl_cleaning_2025.py
│   ├── 05_etl_cleaning_2026.py
│   ├── 06_merge_all_years.py
│   ├── 07_gold_layer_export.py
│   └── mysql_data_loader.ipynb
│
├── 📁 sql/                        ← SQL scripts and outputs
│   ├── star_schema_builder.sql
│   ├── business_queries.sql
│   └── outputs/
│       ├── Query_1_Arbitrage.csv
│       ├── Query_2_Inflation.csv
│       ├── Query_3_Volatility.csv
│       └── Query_4_Seasonality.csv
│
├── 📁 powerbi/
│   └── MandiScope_Dashboard.pbix
│
├── 📁 pdf/
│   ├── model_view_star_schema.png
│   ├── page1_market_overview.png
│   ├── page2_price_intelligence.png
│   └── page3_risk_volatility.png
│
└── README.md
```

---

## Tech Stack

| Technology | Purpose |
|---|---|
| Python 3.13 | ETL pipeline, data cleaning |
| Pandas | Data profiling and transformation |
| SQLAlchemy | Python to MySQL connection engine |
| MySQL 8.0 | Star Schema data warehouse |
| MySQL Workbench | SQL development and execution |
| Power BI Desktop | Interactive executive dashboard |

---

## Key Engineering Decisions

**Why MD5 surrogate keys?**
Using `MD5(CONCAT(...))` generates deterministic, repeatable keys that don't depend on auto-increment. Running the script 100 times produces identical keys — making the pipeline fully idempotent.

**Why Medallion Architecture?**
Separating Bronze/Silver/Gold ensures raw data is always preserved. If cleaning logic changes, raw data can be reprocessed without data loss.

**Why UNION ALL View instead of merging CSVs in Python?**
Pushing year files to MySQL separately then unifying with a VIEW keeps the database layer clean and lets SQL handle the merge — closer to how production data warehouses operate.

**Why STR_TO_DATE with CASE WHEN?**
The raw data contained mixed US format (`01/12/2023`) and Indian format (`01-12-2023`) dates in the same column. A single format string would crash. The CASE WHEN approach handles both formats without data loss.

---

## Results Summary

```
811,131 raw rows ingested
      ↓
266,139 clean rows (32.8% data quality issue rate found and fixed)
      ↓
213,856 fact records in Star Schema
      ↓
4 advanced business intelligence queries
      ↓
3-page executive Power BI dashboard
      ↓
₹79,750 max arbitrage opportunity identified
```

---

## Author

**Abhishek S**
MCA — Sapthagiri NPS University, Bengaluru
📧 abhisheks86609@gmail.com

---

*Built as part of a data engineering portfolio demonstrating end-to-end pipeline development from raw government data to executive business intelligence.*
