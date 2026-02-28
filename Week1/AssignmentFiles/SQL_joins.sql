USE coffeeshop_db;

-- =========================================================
-- JOINS & RELATIONSHIPS PRACTICE
-- =========================================================

-- Q1) Join products to categories: list product_name, category_name, price.
SELECT 
	products.name AS product_name,
    categories.name AS category_name,
    products.price
FROM products
JOIN categories
	ON products.category_id = categories.category_id;

-- Q2) For each order item, show: order_id, order_datetime, store_name,
--     product_name, quantity, line_total (= quantity * products.price).
--     Sort by order_datetime, then order_id.

SELECT
	orders.order_id,
    orders.order_datetime,
    stores.name AS store_name,
    products.name AS product_name,
    order_items.quantity,
    order_items.quantity * products.price AS line_total
FROM order_items
JOIN orders
	ON order_items.order_id = orders.order_id
JOIN products
	ON order_items.product_id = products.product_id
JOIN stores
	ON orders.store_id = stores.store_id
ORDER BY 
	orders.order_datetime,
    orders.order_id;


-- Q3) Customer order history (PAID only):
--     For each order, show customer_name, store_name, order_datetime,
--     order_total (= SUM(quantity * products.price) per order).
SELECT
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
    orders.order_datetime
ORDER BY 
	orders.order_datetime,
    orders.order_id;


-- Q4) Left join to find customers who have never placed an order.
--     Return first_name, last_name, city, state.

SELECT
	customers.first_name AS first_name,
    customers.last_name AS last_name,
	customers.city,
    customers.state
FROM customers
LEFT JOIN orders
	ON customers.customer_id = orders.customer_id
WHERE orders.order_id IS NULL;

-- Q5) For each store, list the top-selling product by units (PAID only).
--     Return store_name, product_name, total_units.
--     Hint: Use a window function (ROW_NUMBER PARTITION BY store) or a correlated subquery.
SELECT
    store_totals.store_name,
    store_totals.product_name,
    store_totals.total_units
FROM (
    SELECT
        stores.store_id,
        stores.name AS store_name,
        products.product_id,
        products.name AS product_name,
        SUM(order_items.quantity) AS total_units
    FROM orders
    JOIN order_items
        ON orders.order_id = order_items.order_id
    JOIN products
        ON order_items.product_id = products.product_id
    JOIN stores
        ON orders.store_id = stores.store_id
    WHERE orders.status = "paid"
    GROUP BY
        stores.store_id,
        stores.name,
        products.product_id,
        products.name
) AS store_totals
WHERE store_totals.total_units = (
    SELECT MAX(inner_totals.total_units)
    FROM (
        SELECT
            SUM(order_items.quantity) AS total_units
        FROM orders
        JOIN order_items
            ON orders.order_id = order_items.order_id
        WHERE orders.status = "paid"
          AND orders.store_id = store_totals.store_id
        GROUP BY order_items.product_id
    ) AS inner_totals
)
ORDER BY store_totals.store_name;
            

-- Q6) Inventory check: show rows where on_hand < 12 in any store.
--     Return store_name, product_name, on_hand.
SELECT
	stores.name AS store_name,
    products.name AS product_name,
    inventory.on_hand
FROM inventory
JOIN stores
	ON inventory.store_id = stores.store_id
JOIN products
	ON inventory.product_id = products.product_id
WHERE inventory.on_hand < 12
ORDER BY 
	stores.name,
    inventory.on_hand,
    products.name;


-- Q7) Manager roster: list each store's manager_name and hire_date.
--     (Assume title = 'Manager').

SELECT
	stores.name AS store_name,
    CONCAT(employees.first_name, ' ', employees.last_name) AS manager_name,
	employees.hire_date
FROM stores
JOIN employees
	ON stores.store_id = employees.store_id
WHERE employees.title = "Manager"
ORDER BY
	stores.name,
    employees.hire_date;


-- Q8) Using a subquery/CTE: list products whose total PAID revenue is above
--     the average PAID product revenue. Return product_name, total_revenue.

SELECT
    store_totals.store_name,
    store_totals.product_name,
    store_totals.total_units
FROM (
    SELECT
        stores.store_id,
        stores.name AS store_name,
        products.product_id,
        products.name AS product_name,
        SUM(order_items.quantity) AS total_units
    FROM orders
    JOIN order_items
        ON orders.order_id = order_items.order_id
    JOIN products
        ON order_items.product_id = products.product_id
    JOIN stores
        ON orders.store_id = stores.store_id
    WHERE orders.status = "paid"
    GROUP BY
        stores.store_id,
        stores.name,
        products.product_id,
        products.name
) AS store_totals
WHERE store_totals.total_units = (
    SELECT MAX(inner_totals.total_units)
    FROM (
        SELECT
            SUM(order_items.quantity) AS total_units
        FROM orders
        JOIN order_items
            ON orders.order_id = order_items.order_id
        WHERE orders.status = "paid"
          AND orders.store_id = store_totals.store_id
        GROUP BY order_items.product_id
    ) AS inner_totals
)
ORDER BY store_totals.store_name;

-- Q9) Churn-ish check: list customers with their last PAID order date.
--     If they have no PAID orders, show NULL.
--     Hint: Put the status filter in the LEFT JOIN's ON clause to preserve non-buyer rows.

SELECT
	customers.customer_id,
    customers.first_name,
    customers.last_name,
    MAX(orders.order_datetime) AS last_paid_order_date
FROM customers
LEFT JOIN orders
	ON customers.customer_id = orders.customer_id
    AND orders.status = "paid"
GROUP BY 
	customers.customer_id,
    customers.first_name,
    customers.last_name
ORDER BY
	customers.last_name,
    customers.first_name;

-- Q10) Product mix report (PAID only):
--     For each store and category, show total units and total revenue (= SUM(quantity * products.price)).
SELECT
    stores.name AS store_name,
    categories.name AS category_name,
    SUM(order_items.quantity) AS total_units,
    SUM(order_items.quantity * products.price) AS total_revenue
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
    categories.category_id,
    categories.name
ORDER BY
    stores.name,
    categories.name;

