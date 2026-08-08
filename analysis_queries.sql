/* =====================================================================
   RETAIL SALES ANALYSIS -- SQL PROJECT
   Author: Piyush Chandra Pandey
   Dataset: 180 customers | 20 products | 600 orders | 1,513 order line items
   Tool: SQLite (portable syntax; works in MySQL/PostgreSQL with minor tweaks)

   Tables:
     customers   (customer_id, customer_name, city, region, signup_date)
     products    (product_id, product_name, category, unit_price)
     orders      (order_id, customer_id, order_date, region)
     order_items (order_item_id, order_id, product_id, quantity, discount_pct)

   This file answers 16 business questions using JOINs, GROUP BY, CASE,
   Subqueries, Window Functions, and CTEs -- organized from basic to advanced.
   ===================================================================== */


/* ---------------------------------------------------------------------
   SECTION 1: FOUNDATIONAL METRICS (GROUP BY, JOINs, Aggregates)
   --------------------------------------------------------------------- */

-- Q1. What is the total revenue and total number of orders?
SELECT
    COUNT(DISTINCT o.order_id)                                   AS total_orders,
    ROUND(SUM(oi.quantity * p.unit_price * (1 - oi.discount_pct/100.0)), 2) AS total_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p      ON p.product_id = oi.product_id;


-- Q2. Which product category generates the most revenue?
SELECT
    p.category,
    ROUND(SUM(oi.quantity * p.unit_price * (1 - oi.discount_pct/100.0)), 2) AS category_revenue,
    COUNT(DISTINCT o.order_id)                                              AS orders_containing_category
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN orders o   ON o.order_id   = oi.order_id
GROUP BY p.category
ORDER BY category_revenue DESC;


-- Q3. What are the top 5 best-selling products by revenue?
SELECT
    p.product_name,
    p.category,
    SUM(oi.quantity)                                             AS units_sold,
    ROUND(SUM(oi.quantity * p.unit_price * (1 - oi.discount_pct/100.0)), 2) AS revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_id
ORDER BY revenue DESC
LIMIT 5;


-- Q4. How does revenue break down by region?
SELECT
    o.region,
    COUNT(DISTINCT o.order_id)                                   AS orders,
    ROUND(SUM(oi.quantity * p.unit_price * (1 - oi.discount_pct/100.0)), 2) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p      ON p.product_id = oi.product_id
GROUP BY o.region
ORDER BY revenue DESC;


-- Q5. What is the month-over-month order trend? (basic time series with GROUP BY)
SELECT
    strftime('%Y-%m', order_date) AS order_month,
    COUNT(DISTINCT order_id)      AS orders
FROM orders
GROUP BY order_month
ORDER BY order_month;


/* ---------------------------------------------------------------------
   SECTION 2: CUSTOMER SEGMENTATION (CASE, JOINs, HAVING)
   --------------------------------------------------------------------- */

-- Q6. Segment customers into High / Medium / Low value tiers based on total spend.
SELECT
    c.customer_id,
    c.customer_name,
    ROUND(SUM(oi.quantity * p.unit_price * (1 - oi.discount_pct/100.0)), 2) AS total_spend,
    CASE
        WHEN SUM(oi.quantity * p.unit_price * (1 - oi.discount_pct/100.0)) >= 15000 THEN 'High Value'
        WHEN SUM(oi.quantity * p.unit_price * (1 - oi.discount_pct/100.0)) >= 5000  THEN 'Medium Value'
        ELSE 'Low Value'
    END AS customer_tier
FROM customers c
JOIN orders o       ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
JOIN products p     ON p.product_id  = oi.product_id
GROUP BY c.customer_id
ORDER BY total_spend DESC;


-- Q7. How many customers fall into each value tier, and what % of total revenue do they drive?
-- (CTE + CASE + aggregate -- shows how tiers are built on top of each other)
WITH customer_spend AS (
    SELECT
        c.customer_id,
        SUM(oi.quantity * p.unit_price * (1 - oi.discount_pct/100.0)) AS total_spend
    FROM customers c
    JOIN orders o       ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id   = o.order_id
    JOIN products p     ON p.product_id  = oi.product_id
    GROUP BY c.customer_id
),
tiered AS (
    SELECT
        *,
        CASE
            WHEN total_spend >= 15000 THEN 'High Value'
            WHEN total_spend >= 5000  THEN 'Medium Value'
            ELSE 'Low Value'
        END AS customer_tier
    FROM customer_spend
)
SELECT
    customer_tier,
    COUNT(*)                                              AS num_customers,
    ROUND(SUM(total_spend), 2)                            AS tier_revenue,
    ROUND(100.0 * SUM(total_spend) / (SELECT SUM(total_spend) FROM customer_spend), 1) AS pct_of_total_revenue
FROM tiered
GROUP BY customer_tier
ORDER BY tier_revenue DESC;


-- Q8. Which customers are "at risk" -- signed up but never placed a repeat order?
SELECT
    c.customer_id,
    c.customer_name,
    c.signup_date,
    COUNT(o.order_id) AS total_orders
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id
HAVING COUNT(o.order_id) <= 1
ORDER BY c.signup_date;


/* ---------------------------------------------------------------------
   SECTION 3: SUBQUERIES
   --------------------------------------------------------------------- */

-- Q9. Which customers spent more than the average customer spend? (subquery in WHERE)
SELECT
    customer_id,
    customer_name,
    total_spend
FROM (
    SELECT
        c.customer_id,
        c.customer_name,
        SUM(oi.quantity * p.unit_price * (1 - oi.discount_pct/100.0)) AS total_spend
    FROM customers c
    JOIN orders o       ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id   = o.order_id
    JOIN products p     ON p.product_id  = oi.product_id
    GROUP BY c.customer_id
) AS customer_totals
WHERE total_spend > (
    SELECT AVG(sub.total_spend)
    FROM (
        SELECT SUM(oi2.quantity * p2.unit_price * (1 - oi2.discount_pct/100.0)) AS total_spend
        FROM orders o2
        JOIN order_items oi2 ON oi2.order_id  = o2.order_id
        JOIN products p2     ON p2.product_id = oi2.product_id
        GROUP BY o2.customer_id
    ) AS sub
)
ORDER BY total_spend DESC;


-- Q10. Which products have never been ordered with a discount? (correlated subquery / NOT IN)
SELECT product_name, category, unit_price
FROM products
WHERE product_id NOT IN (
    SELECT DISTINCT product_id FROM order_items WHERE discount_pct > 0
);


/* ---------------------------------------------------------------------
   SECTION 4: WINDOW FUNCTIONS
   --------------------------------------------------------------------- */

-- Q11. Rank customers by total spend within each region (RANK + PARTITION BY).
WITH customer_region_spend AS (
    SELECT
        c.customer_id,
        c.customer_name,
        o.region,
        SUM(oi.quantity * p.unit_price * (1 - oi.discount_pct/100.0)) AS total_spend
    FROM customers c
    JOIN orders o       ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id   = o.order_id
    JOIN products p     ON p.product_id  = oi.product_id
    GROUP BY c.customer_id, o.region
),
ranked AS (
    SELECT
        region,
        customer_name,
        ROUND(total_spend, 2) AS total_spend,
        RANK() OVER (PARTITION BY region ORDER BY total_spend DESC) AS regional_rank
    FROM customer_region_spend
)
SELECT * FROM ranked
WHERE regional_rank <= 3
ORDER BY region, regional_rank;


-- Q12. Running total of monthly revenue (SUM ... OVER for a cumulative trend).
WITH monthly_revenue AS (
    SELECT
        strftime('%Y-%m', o.order_date) AS order_month,
        SUM(oi.quantity * p.unit_price * (1 - oi.discount_pct/100.0)) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id  = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    GROUP BY order_month
)
SELECT
    order_month,
    ROUND(revenue, 2) AS monthly_revenue,
    ROUND(SUM(revenue) OVER (ORDER BY order_month), 2) AS running_total_revenue
FROM monthly_revenue
ORDER BY order_month;


-- Q13. Month-over-month revenue growth % (LAG window function).
WITH monthly_revenue AS (
    SELECT
        strftime('%Y-%m', o.order_date) AS order_month,
        SUM(oi.quantity * p.unit_price * (1 - oi.discount_pct/100.0)) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id  = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    GROUP BY order_month
)
SELECT
    order_month,
    ROUND(revenue, 2) AS revenue,
    ROUND(LAG(revenue) OVER (ORDER BY order_month), 2) AS prev_month_revenue,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
        / NULLIF(LAG(revenue) OVER (ORDER BY order_month), 0), 1
    ) AS mom_growth_pct
FROM monthly_revenue
ORDER BY order_month;


-- Q14. For each customer, flag their first vs. repeat orders using ROW_NUMBER().
SELECT
    customer_id,
    order_id,
    order_date,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS order_sequence,
    CASE
        WHEN ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) = 1 THEN 'First Order'
        ELSE 'Repeat Order'
    END AS order_type
FROM orders
ORDER BY customer_id, order_date;


/* ---------------------------------------------------------------------
   SECTION 5: COHORT / RETENTION ANALYSIS (CTEs)
   --------------------------------------------------------------------- */

-- Q15. Monthly cohort retention: of customers who made their first purchase in a
--      given month, how many were still ordering 1, 2, and 3 months later?
WITH first_purchase AS (
    SELECT
        customer_id,
        MIN(strftime('%Y-%m', order_date)) AS cohort_month
    FROM orders
    GROUP BY customer_id
),
order_activity AS (
    SELECT
        o.customer_id,
        fp.cohort_month,
        strftime('%Y-%m', o.order_date) AS order_month,
        CAST(
            (strftime('%Y', o.order_date) - strftime('%Y', fp.cohort_month || '-01')) * 12
            + (strftime('%m', o.order_date) - strftime('%m', fp.cohort_month || '-01'))
            AS INTEGER
        ) AS month_offset
    FROM orders o
    JOIN first_purchase fp ON fp.customer_id = o.customer_id
)
SELECT
    cohort_month,
    month_offset,
    COUNT(DISTINCT customer_id) AS active_customers
FROM order_activity
WHERE month_offset BETWEEN 0 AND 3
GROUP BY cohort_month, month_offset
ORDER BY cohort_month, month_offset;


-- Q16. Customer Lifetime Value (CLV) proxy: total spend, order count, and average
--      order value per customer, with a repeat-purchase flag -- a common
--      "final output" business teams ask for.
WITH customer_orders AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.region,
        COUNT(DISTINCT o.order_id) AS num_orders,
        SUM(oi.quantity * p.unit_price * (1 - oi.discount_pct/100.0)) AS total_spend
    FROM customers c
    JOIN orders o       ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id   = o.order_id
    JOIN products p     ON p.product_id  = oi.product_id
    GROUP BY c.customer_id
)
SELECT
    customer_id,
    customer_name,
    region,
    num_orders,
    ROUND(total_spend, 2)                    AS total_spend,
    ROUND(total_spend / num_orders, 2)       AS avg_order_value,
    CASE WHEN num_orders > 1 THEN 'Repeat Customer' ELSE 'One-Time Customer' END AS customer_status
FROM customer_orders
ORDER BY total_spend DESC;
