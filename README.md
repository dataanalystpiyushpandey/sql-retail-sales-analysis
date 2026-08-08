# SQL Retail Sales Analysis

A SQL project analysing a relational retail dataset to answer 16 real business questions — from basic revenue reporting to customer segmentation, cohort retention, and lifetime value analysis.

## 📊 Dataset
- **Tables:** customers, products, orders, order_items
- **Scale:** 180 customers | 20 products across 6 categories | 600 orders | 1,513 order line items
- **Time range:** January 2023 – June 2025 (30 months)
- **Tool:** SQLite (portable ANSI-standard SQL; adapts easily to MySQL/PostgreSQL)

## 🛠 SQL Concepts Demonstrated
- Aggregations & GROUP BY
- Multi-table JOINs
- CASE-based customer segmentation
- Subqueries (nested & correlated)
- Window functions (RANK, ROW_NUMBER, LAG, running SUM)
- CTEs (Common Table Expressions) for cohort retention and multi-step analysis

## 📁 Files
| File | Description |
|---|---|
| `retail_sales.db` | SQLite database — open in [DB Browser for SQLite](https://sqlitebrowser.org/) (free) to explore tables and re-run queries |
| `analysis_queries.sql` | All 16 business-question queries, fully commented, organised by technique |

## 🔍 Sample Findings
- Just **75 High Value customers (out of 180)** generate **79.5% of total revenue** — a classic 80/20 pattern
- **68 customers (38%)** placed only one order and never returned — a clear win-back opportunity
- The **South region** outperforms all others in both order volume and revenue
- **Electronics** is the top revenue category, followed by Fitness and Home

## 👤 Author
**Piyush Chandra Pandey**
📧 digitalpiyush31@gmail.com
🔗 [LinkedIn](https://www.linkedin.com/in/piyush-pandey-dataanalyst/)
