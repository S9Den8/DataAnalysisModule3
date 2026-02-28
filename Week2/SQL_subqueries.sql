USE coffeeshop_db;

-- =========================================================
-- SUBQUERIES & NESTED LOGIC PRACTICE
-- =========================================================

-- Q1) Scalar subquery (AVG benchmark):
--     List products priced above the overall average product price.
--     Return product_id, name, price.
SELECT 
	product_id,
    name,
    price
FROM products
Where price > (SELECT AVG(price) FROM products);

-- Q2) Scalar subquery (MAX within category):
--     Find the most expensive product(s) in the 'Beans' category.
--     (Return all ties if more than one product shares the max price.)
--     Return product_id, name, price.

SELECT 
	products.product_id,
    products.name,
    products.price
FROM products
WHERE products.category_id = (
	SELECT categories.category_id
    FROM categories
    WHERE categories.name = "Beans"
)
AND products.price = (
	SELECT MAX(products.price)
    FROM products
    WHERE products.category_id = (
		SELECT categories.category_id
        FROM categories
        WHERE categories.name = "Beans"
        )
	);

-- Q3) List subquery (IN with nested lookup):
--     List customers who have purchased at least one product in the 'Merch' category.
--     Return customer_id, first_name, last_name.
--     Hint: Use a subquery to find the category_id for 'Merch', then a subquery to find product_ids.

SELECT 
	customers.customer_id,
    customers.first_name,
    customers.last_name
FROM customers
WHERE customers.customer_id IN (
	SELECT orders.customer_id
    FROM orders
    WHERE orders.order_id IN (
		SELECT order_items.order_id
        FROM order_items
        WHERE order_items.product_id IN (
			SELECT products.product_id
            FROM products
            WHERE products.category_id = (
				SELECT categories.category_id
                FROM categories
                WHERE categories.name = "Merch"
			)
		)
	)
);
        

-- Q4) List subquery (NOT IN / anti-join logic):
--     List products that have never been ordered (their product_id never appears in order_items).
--     Return product_id, name, price.

SELECT 
	products.product_id,
    products.name,
    products.price
FROM products
WHERE products.product_id NOT IN (
	SELECT order_items.product_id
    FROM order_items
    WHERE order_items.product_id IS NOT NULL
);

-- Checking to verify the 0 results are indeed order --> how many products exist
SELECT COUNT(*) FROM products;

-- How many distinct producst appear in orders?
SELECT COUNT(distinct order_items.product_id)
FROM order_items;


-- Q5) Table subquery (derived table + compare to overall average):
--     Build a derived table that computes total_units_sold per product
--     (SUM(order_items.quantity) grouped by product_id).
--     Then return only products whose total_units_sold is greater than the
--     average total_units_sold across all products.
--     Return product_id, product_name, total_units_sold.

SELECT
    products.product_id,
    products.name AS product_name,
    totals.total_units_sold
FROM
    products
JOIN
    (
        SELECT
            order_items.product_id,
            SUM(order_items.quantity) AS total_units_sold
        FROM
            order_items
        GROUP BY
            order_items.product_id
    ) AS totals
ON products.product_id = totals.product_id
WHERE
    totals.total_units_sold > (
        SELECT
            AVG(product_totals.total_units_sold)
        FROM
            (
                SELECT
                    SUM(order_items.quantity) AS total_units_sold
                FROM
                    order_items
                GROUP BY
                    order_items.product_id
            ) AS product_totals
    );