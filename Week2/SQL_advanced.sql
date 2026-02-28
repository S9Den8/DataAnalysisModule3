USE coffeeshop_db;

-- =========================================================
-- ADVANCED SQL ASSIGNMENT
-- Subqueries, CTEs, Window Functions, Views
-- =========================================================
-- Notes:
-- - Unless a question says otherwise, use orders with status = 'paid'.
-- - Write ONE query per prompt.
-- - Keep results readable (use clear aliases, ORDER BY where it helps).

-- =========================================================
-- Q1) Correlated subquery: Above-average order totals (PAID only)
-- =========================================================
-- For each PAID order, compute order_total (= SUM(quantity * products.price)).
-- Return: order_id, customer_name, store_name, order_datetime, order_total.
-- Filter to orders where order_total is greater than the average PAID order_total
-- for THAT SAME store (correlated subquery).
-- Sort by store_name, then order_total DESC.

SELECT
    orders.order_id,
    customers.first_name,
    customers.last_name,
    stores.name AS store_name,
    orders.order_datetime,
    SUM(order_items.quantity * products.price) AS order_total
FROM orders
JOIN customers
    ON orders.customer_id = customers.customer_id
JOIN stores
    ON orders.store_id = stores.store_id
JOIN order_items
    ON orders.order_id = order_items.order_id
JOIN products
    ON order_items.product_id = products.product_id
WHERE orders.status = "paid"
GROUP BY
    orders.order_id,
    customers.first_name,
    customers.last_name,
    stores.name,
    orders.order_datetime,
    orders.store_id
HAVING SUM(order_items.quantity * products.price) >
    (
        SELECT AVG(store_totals.order_total)
        FROM (
            SELECT
                orders_inner.order_id,
                SUM(order_items_inner.quantity * products_inner.price) AS order_total
            FROM orders AS orders_inner
            JOIN order_items AS order_items_inner
                ON orders_inner.order_id = order_items_inner.order_id
            JOIN products AS products_inner
                ON order_items_inner.product_id = products_inner.product_id
            WHERE orders_inner.status = "paid"
              AND orders_inner.store_id = orders.store_id
            GROUP BY orders_inner.order_id
        ) AS store_totals
    )
ORDER BY
    store_name,
    order_total DESC;


-- =========================================================
-- Q2) CTE: Daily revenue and 3-day rolling average (PAID only)
-- =========================================================
-- Using a CTE, compute daily revenue per store:
--   revenue_day = SUM(quantity * products.price) grouped by store_id and DATE(order_datetime).
-- Then, for each store and date, return:
--   store_name, order_date, revenue_day,
--   rolling_3day_avg = average of revenue_day over the current day and the prior 2 days.
-- Use a window function for the rolling average.
-- Sort by store_name, order_date.


WITH daily_revenue AS (
	SELECT
		stores.store_id,
        stores.name AS store_name,
        DATE(orders.order_datetime) AS order_date,
        SUM(order_items.quantity * products.price) AS revenue_day
	FROM orders
    JOIN order_items
		ON order_items.order_id = orders.order_id
	JOIN products
		ON products.product_id = order_items.product_id
	JOIN stores
		ON stores.store_id = orders.store_id
	WHERE orders.status = "paid"
    GROUP BY 
		stores.store_id,
        stores.name,
        DATE(orders.order_datetime)
	) 
    SELECT 
		store_name,
        order_date,
        revenue_day,
        AVG(revenue_day) OVER (
			partition by store_id
            Order by order_date
            ROWS between 2 preceding and CURRENT row
		) AS rolling_3day_avg
	FROM daily_revenue 
    ORDER BY 
		store_name,
        order_date;

-- =========================================================
-- Q3) Window function: Rank customers by lifetime spend (PAID only)
-- =========================================================
-- Compute each customer's total spend across ALL stores (PAID only).
-- Return: customer_id, customer_name, total_spend,
--         spend_rank (DENSE_RANK by total_spend DESC).
-- Also include percent_of_total = customer's total_spend / total spend of all customers.
-- Sort by total_spend DESC.

WITH customer_spend AS (
    SELECT
        customers.customer_id,
        CONCAT(customers.first_name, " ", customers.last_name) AS customer_name,
        SUM(order_items.quantity * products.price) AS total_spend
    FROM orders
    JOIN customers
        ON orders.customer_id = customers.customer_id
    JOIN order_items
        ON orders.order_id = order_items.order_id
    JOIN products
        ON order_items.product_id = products.product_id
    WHERE orders.status = "paid"
    GROUP BY
        customers.customer_id,
        customers.first_name,
        customers.last_name
)
SELECT
    customer_id,
    customer_name,
    total_spend,
    DENSE_RANK() OVER (ORDER BY total_spend DESC) AS spend_rank,
    total_spend / SUM(total_spend) OVER () AS percent_of_total
FROM customer_spend
ORDER BY total_spend DESC;



-- =========================================================
-- Q4) CTE + window: Top product per store by revenue (PAID only)
-- =========================================================
-- For each store, find the top-selling product by REVENUE (not units).
-- Revenue per product per store = SUM(quantity * products.price).
-- Return: store_name, product_name, category_name, product_revenue.
-- Use a CTE to compute product_revenue, then a window function (ROW_NUMBER)
-- partitioned by store to select the top 1.
-- Sort by store_name.

with product_revenue AS (
	SELECT
		stores.store_id,
        stores.name AS store_name,
        products.name AS product_name,
        categories.name AS category_name,
        SUM(order_items.quantity * products.price) AS product_revenue
	FROM orders
    JOIN order_items
		ON orders.order_id = order_items.order_id
	JOIN products
		ON order_items.product_id = products.product_id
	JOIN categories
		ON products.category_id = categories.category_id
	JOIN stores
		ON orders.store_id = stores.store_id
	WHERE orders.status = "paid"
    GROUP BY 
		stores.store_id,
        stores.name,
        products.product_id,
        products.name,
        categories.name
	)
    
    SELECT 
		store_name,
        product_name,
        category_name,
        product_revenue
	FROM (
		SELECT
			store_name,
            product_name,
            category_name,
            product_revenue,
            ROW_NUMBER() OVER (
				Partition by store_name
                ORDER BY product_revenue DESC
			) AS row_num
		FROM product_revenue
	) ranked
    WHERE row_num = 1
    ORDER BY store_name;
    

-- =========================================================
-- Q5) Subquery: Customers who have ordered from ALL stores (PAID only)
-- =========================================================
-- Return customers who have at least one PAID order in every store in the stores table.
-- Return: customer_id, customer_name.
-- Hint: Compare count(distinct store_id) per customer to (select count(*) from stores).
 
SELECT
	customers.customer_id,
    CONCAT(customers.first_name, " ", customers.last_name) AS customer_name
FROM customers
JOIN orders
	ON customers.customer_id = orders.customer_id
WHERE orders.status = "paid"
GROUP BY 
	customers.customer_id,
    customers.first_name,
    customers.last_name
HAVING COUNT(DISTINCT orders.store_id) = (SELECT COUNT(*) FROM stores)
ORDER BY customer_name;


-- =========================================================
-- Q6) Window function: Time between orders per customer (PAID only)
-- =========================================================
-- For each customer, list their PAID orders in chronological order and compute:
--   prev_order_datetime (LAG),
--   minutes_since_prev (difference in minutes between current and previous order).
-- Return: customer_name, order_id, order_datetime, prev_order_datetime, minutes_since_prev.
-- Only show rows where prev_order_datetime is NOT NULL.
-- Sort by customer_name, order_datetime.

WITH paid_orders AS (
    SELECT
        customers.customer_id,
        CONCAT(customers.first_name, ' ', customers.last_name) AS customer_name,
        orders.order_id,
        orders.order_datetime,
        LAG(orders.order_datetime) OVER (
            PARTITION BY customers.customer_id
            ORDER BY orders.order_datetime
        ) AS prev_order_datetime
    FROM customers
    JOIN orders
        ON customers.customer_id = orders.customer_id
    WHERE orders.status = 'paid'
)
SELECT
    customer_name,
    order_id,
    order_datetime,
    prev_order_datetime,
    TIMESTAMPDIFF(MINUTE, prev_order_datetime, order_datetime) AS minutes_since_prev
FROM paid_orders
WHERE prev_order_datetime IS NOT NULL
ORDER BY customer_name, order_datetime;


-- =========================================================
-- Q7) View: Create a reusable order line view for PAID orders
-- =========================================================
-- Create a view named v_paid_order_lines that returns one row per PAID order item:
--   order_id, order_datetime, store_id, store_name,
--   customer_id, customer_name,
--   product_id, product_name, category_name,
--   quantity, unit_price (= products.price),
--   line_total (= quantity * products.price)

CREATE OR REPLACE VIEW v_paid_order_lines AS
SELECT
    orders.order_id,
    orders.order_datetime,
    stores.store_id,
    stores.name AS store_name,
    customers.customer_id,
    CONCAT(customers.first_name, ' ', customers.last_name) AS customer_name,
    products.product_id,
    products.name AS product_name,
    categories.name AS category_name,
    order_items.quantity,
    products.price AS unit_price,
    (order_items.quantity * products.price) AS line_total
FROM orders
JOIN customers
    ON orders.customer_id = customers.customer_id
JOIN stores
    ON orders.store_id = stores.store_id
JOIN order_items
    ON orders.order_id = order_items.order_id
JOIN products
    ON order_items.product_id = products.product_id
JOIN categories
    ON products.category_id = categories.category_id
WHERE orders.status = 'paid';

-- After creating the view, write a SELECT that uses the view to return:
--   store_name, category_name, revenue
-- where revenue is SUM(line_total),
-- sorted by revenue DESC.

SELECT
	store_name,
    category_name,
    SUM(line_total) AS revenue
FROM v_paid_order_lines
GROUP BY 
	store_name,
    category_name
ORDER BY revenue DESC;


-- =========================================================
-- Q8) View + window: Store revenue share by payment method (PAID only)
-- =========================================================
-- Create a view named v_paid_store_payments with:
--   store_id, store_name, payment_method, revenue
-- where revenue is total PAID revenue for that store/payment_method.

CREATE OR REPLACE VIEW v_paid_store_payments AS
SELECT
    stores.store_id,
    stores.name AS store_name,
    orders.payment_method,
    SUM(order_items.quantity * products.price) AS revenue
FROM orders
JOIN stores
    ON orders.store_id = stores.store_id
JOIN order_items
    ON orders.order_id = order_items.order_id
JOIN products
    ON order_items.product_id = products.product_id
WHERE orders.status = 'paid'
GROUP BY
    stores.store_id,
    stores.name,
    orders.payment_method;


-- Then query the view to return:
--   store_name, payment_method, revenue,
--   store_total_revenue (window SUM over store),
--   pct_of_store_revenue (= revenue / store_total_revenue)
-- Sort by store_name, revenue DESC.

SELECT
	store_name,
    payment_method,
    revenue, 
    SUM(revenue) OVER (partition by store_name) AS store_total_revenue,
    revenue / SUM(revenue) OVER (partition by store_name) AS pct_of_store_revenue
FROM v_paid_store_payments
ORDER BY 
	store_name,
    revenue DESC;


-- =========================================================
-- Q9) CTE: Inventory risk report (low stock relative to sales)
-- =========================================================
-- Identify items where on_hand is low compared to recent demand:
-- Using a CTE, compute total_units_sold per store/product for PAID orders.
-- Then join inventory to that result and return rows where:
--   on_hand < total_units_sold
-- Return: store_name, product_name, on_hand, total_units_sold, units_gap (= total_units_sold - on_hand)
-- Sort by units_gap DESC.

CREATE OR REPLACE VIEW v_paid_store_payments AS
SELECT
    stores.store_id,
    stores.name AS store_name,
    orders.payment_method,
    SUM(order_items.quantity * products.price) AS revenue
FROM orders
JOIN stores
    ON orders.store_id = stores.store_id
JOIN order_items
    ON orders.order_id = order_items.order_id
JOIN products
    ON order_items.product_id = products.product_id
WHERE orders.status = 'paid'
GROUP BY
    stores.store_id,
    stores.name,
    orders.payment_method;


