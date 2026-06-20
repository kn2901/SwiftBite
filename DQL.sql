-- ============================================================
--  FOOD DELIVERY SYSTEM — SQL QUERIES
--  Database: PostgreSQL
-- ============================================================


-- ============================================================
-- SECTION 1: BASIC QUERIES
-- Simple SELECT, WHERE, ORDER BY, LIMIT
-- ============================================================


-- Q1: Get all restaurants that are currently open
SELECT restaurant_id, name, address, rating
FROM restaurant
WHERE is_open = TRUE;


-- Q2: Get all available delivery persons
SELECT u.full_name, u.phone, dp.rating
FROM "user" u
JOIN delivery_person dp ON dp.user_id = u.user_id
WHERE dp.status = 'available';


-- Q3: Get all menu items of a specific restaurant (restaurant_id = 1)
-- sorted by price low to high
SELECT name, description, price, is_available
FROM menu_item
WHERE restaurant_id = 1
ORDER BY price ASC;


-- Q4: Get all menu items that are available and cost less than 200
SELECT name, price
FROM menu_item
WHERE is_available = TRUE
AND price < 200
ORDER BY price ASC;


-- Q5: Get all orders placed by a specific customer (user_id = 3)
-- most recent first
SELECT order_id, delivery_address, total_amount, status, placed_at
FROM "order"
WHERE user_id = 3
ORDER BY placed_at DESC;


-- Q6: Get all pending or failed payments
SELECT payment_id, order_id, amount, method, status
FROM payment
WHERE status IN ('pending', 'failed')
ORDER BY payment_id;


-- Q7: Get top 5 highest rated restaurants
SELECT name, address, rating
FROM restaurant
WHERE rating IS NOT NULL
ORDER BY rating DESC
LIMIT 5;


-- Q8: Get all cancelled orders
SELECT order_id, user_id, restaurant_id, total_amount, placed_at
FROM "order"
WHERE status = 'cancelled';


-- Q9: Get all addresses saved by a specific customer (user_id = 2)
SELECT label, address, is_default
FROM user_address
WHERE user_id = 2;


-- Q10: Get all menu items that belong to a specific category (category_id = 1)
SELECT name, price, is_available
FROM menu_item
WHERE category_id = 1
ORDER BY name;


-- ============================================================
-- SECTION 2: JOIN QUERIES
-- Combining data from multiple tables
-- ============================================================


-- Q11: Get order details with customer name and restaurant name
-- (INNER JOIN — only orders that have matching user and restaurant)
SELECT
    o.order_id,
    u.full_name      AS customer_name,
    r.name           AS restaurant_name,
    o.total_amount,
    o.status,
    o.placed_at
FROM "order" o
JOIN "user"      u ON u.user_id       = o.user_id
JOIN restaurant  r ON r.restaurant_id = o.restaurant_id
ORDER BY o.placed_at DESC;


-- Q12: Get all items in a specific order (order_id = 5)
-- with item name and subtotal
SELECT
    m.name                              AS item_name,
    oi.quantity,
    oi.unit_price,
    oi.quantity * oi.unit_price         AS subtotal
FROM order_item oi
JOIN menu_item m ON m.item_id = oi.item_id
WHERE oi.order_id = 5;


-- Q13: Get cart contents for a specific customer (user_id = 2)
-- with item name, quantity, price and subtotal
SELECT
    r.name                              AS restaurant_name,
    m.name                              AS item_name,
    ci.quantity,
    ci.unit_price,
    ci.quantity * ci.unit_price         AS subtotal
FROM cart c
JOIN cart_item  ci ON ci.cart_id       = c.cart_id
JOIN menu_item  m  ON m.item_id        = ci.item_id
JOIN restaurant r  ON r.restaurant_id  = c.restaurant_id
WHERE c.user_id = 2;


-- Q14: Get delivery details with delivery person name and order status
SELECT
    d.delivery_id,
    o.order_id,
    u.full_name     AS delivery_person,
    o.status        AS order_status,
    d.status        AS delivery_status,
    d.assigned_at,
    d.picked_at,
    d.delivered_at
FROM delivery d
JOIN "order"        o ON o.order_id  = d.order_id
JOIN delivery_person dp ON dp.user_id = d.dp_user_id
JOIN "user"          u ON u.user_id   = dp.user_id;


-- Q15: Get all restaurants with their categories
-- (a restaurant can have multiple categories)
SELECT
    r.name          AS restaurant_name,
    c.name          AS category
FROM restaurant r
JOIN restaurant_category rc ON rc.restaurant_id = r.restaurant_id
JOIN category            c  ON c.category_id    = rc.category_id
ORDER BY r.name, c.name;


-- Q16: Get all payment attempts for a specific order (order_id = 3)
SELECT
    p.payment_id,
    p.method,
    p.amount,
    p.status,
    p.transaction_id,
    p.paid_at
FROM payment p
WHERE p.order_id = 3
ORDER BY p.payment_id;


-- Q17: LEFT JOIN — Get all restaurants and their menu item count
-- including restaurants with NO items (count = 0)
SELECT
    r.name              AS restaurant_name,
    COUNT(m.item_id)    AS total_items
FROM restaurant r
LEFT JOIN menu_item m ON m.restaurant_id = r.restaurant_id
GROUP BY r.restaurant_id, r.name
ORDER BY total_items DESC;


-- Q18: Get all customers who have placed at least one order
-- with their total number of orders
SELECT
    u.user_id,
    u.full_name,
    u.email,
    COUNT(o.order_id) AS total_orders
FROM "user" u
JOIN "order" o ON o.user_id = u.user_id
WHERE u.role = 'customer'
GROUP BY u.user_id, u.full_name, u.email
ORDER BY total_orders DESC;


-- Q19: Get full order summary — customer, restaurant, items, payment
SELECT
    o.order_id,
    u.full_name             AS customer,
    r.name                  AS restaurant,
    m.name                  AS item_name,
    oi.quantity,
    oi.unit_price,
    o.total_amount,
    p.method                AS payment_method,
    p.status                AS payment_status
FROM "order" o
JOIN "user"       u  ON u.user_id       = o.user_id
JOIN restaurant   r  ON r.restaurant_id = o.restaurant_id
JOIN order_item   oi ON oi.order_id     = o.order_id
JOIN menu_item    m  ON m.item_id       = oi.item_id
LEFT JOIN payment p  ON p.order_id      = o.order_id
AND p.status = 'completed'
ORDER BY o.order_id;


-- Q20: Get all delivery persons with their current status and rating
-- including users who are delivery persons (JOIN from user)
SELECT
    u.full_name,
    u.phone,
    dp.status,
    dp.rating
FROM "user" u
JOIN delivery_person dp ON dp.user_id = u.user_id
ORDER BY dp.status, dp.rating DESC;


-- ============================================================
-- SECTION 3: AGGREGATE QUERIES
-- COUNT, SUM, AVG, GROUP BY, HAVING
-- ============================================================


-- Q21: Total revenue per restaurant
SELECT
    r.name              AS restaurant_name,
    COUNT(o.order_id)   AS total_orders,
    SUM(o.total_amount) AS total_revenue
FROM restaurant r
JOIN "order" o ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'delivered'
GROUP BY r.restaurant_id, r.name
ORDER BY total_revenue DESC;


-- Q22: Average order value per customer
SELECT
    u.full_name,
    COUNT(o.order_id)       AS total_orders,
    ROUND(AVG(o.total_amount), 2) AS avg_order_value
FROM "user" u
JOIN "order" o ON o.user_id = u.user_id
GROUP BY u.user_id, u.full_name
ORDER BY avg_order_value DESC;


-- Q23: Number of orders per status
-- Useful for admin dashboard
SELECT
    status,
    COUNT(*) AS order_count
FROM "order"
GROUP BY status
ORDER BY order_count DESC;


-- Q24: Most ordered menu items (by total quantity sold)
SELECT
    m.name              AS item_name,
    SUM(oi.quantity)    AS total_quantity_sold,
    COUNT(oi.order_id)  AS times_ordered
FROM menu_item m
JOIN order_item oi ON oi.item_id = m.item_id
GROUP BY m.item_id, m.name
ORDER BY total_quantity_sold DESC
LIMIT 10;


-- Q25: Restaurants with more than 50 total orders
-- HAVING filters after GROUP BY
SELECT
    r.name              AS restaurant_name,
    COUNT(o.order_id)   AS total_orders
FROM restaurant r
JOIN "order" o ON o.restaurant_id = r.restaurant_id
GROUP BY r.restaurant_id, r.name
HAVING COUNT(o.order_id) > 50
ORDER BY total_orders DESC;


-- Q26: Total earnings per delivery person
SELECT
    u.full_name             AS delivery_person,
    COUNT(d.delivery_id)    AS total_deliveries,
    dp.rating
FROM "user" u
JOIN delivery_person dp ON dp.user_id  = u.user_id
JOIN delivery        d  ON d.dp_user_id = u.user_id
WHERE d.status = 'delivered'
GROUP BY u.user_id, u.full_name, dp.rating
ORDER BY total_deliveries DESC;


-- Q27: Revenue collected per payment method
SELECT
    method,
    COUNT(*)            AS transaction_count,
    SUM(amount)         AS total_collected
FROM payment
WHERE status = 'completed'
GROUP BY method
ORDER BY total_collected DESC;


-- Q28: Customers who have spent more than 1000 total
SELECT
    u.full_name,
    SUM(o.total_amount) AS total_spent
FROM "user" u
JOIN "order" o ON o.user_id = u.user_id
WHERE o.status = 'delivered'
GROUP BY u.user_id, u.full_name
HAVING SUM(o.total_amount) > 1000
ORDER BY total_spent DESC;


-- ============================================================
-- SECTION 4: SUBQUERIES
-- A query inside another query
-- ============================================================


-- Q29: Get all menu items that have never been ordered
-- Subquery returns all item_ids that appear in order_item
SELECT name, price
FROM menu_item
WHERE item_id NOT IN (
    SELECT DISTINCT item_id FROM order_item
);


-- Q30: Get customers who have never placed an order
SELECT full_name, email
FROM "user"
WHERE role = 'customer'
AND user_id NOT IN (
    SELECT DISTINCT user_id FROM "order"
);


-- Q31: Get the most expensive item in each restaurant
-- Subquery finds max price per restaurant
SELECT
    r.name          AS restaurant_name,
    m.name          AS item_name,
    m.price
FROM menu_item m
JOIN restaurant r ON r.restaurant_id = m.restaurant_id
WHERE m.price = (
    SELECT MAX(price)
    FROM menu_item
    WHERE restaurant_id = m.restaurant_id
)
ORDER BY m.price DESC;


-- Q32: Get orders whose total is above the average order value
SELECT
    order_id,
    user_id,
    total_amount,
    status
FROM "order"
WHERE total_amount > (
    SELECT AVG(total_amount) FROM "order"
)
ORDER BY total_amount DESC;


-- Q33: Get restaurants that have no orders yet
SELECT name, address
FROM restaurant
WHERE restaurant_id NOT IN (
    SELECT DISTINCT restaurant_id FROM "order"
);


-- Q34: Get the details of the highest paid delivery person
-- (most deliveries completed)
SELECT
    u.full_name,
    u.phone,
    dp.rating
FROM "user" u
JOIN delivery_person dp ON dp.user_id = u.user_id
WHERE u.user_id = (
    SELECT dp_user_id
    FROM delivery
    WHERE status = 'delivered'
    GROUP BY dp_user_id
    ORDER BY COUNT(*) DESC
    LIMIT 1
);


-- ============================================================
-- SECTION 5: WINDOW FUNCTIONS
-- PostgreSQL specialty — powerful for ranking and analytics
-- OVER() defines the window (partition/order)
-- ============================================================


-- Q35: Rank customers by total amount spent
-- RANK() assigns same rank for ties
SELECT
    u.full_name,
    SUM(o.total_amount)                             AS total_spent,
    RANK() OVER (ORDER BY SUM(o.total_amount) DESC) AS spending_rank
FROM "user" u
JOIN "order" o ON o.user_id = u.user_id
WHERE o.status = 'delivered'
GROUP BY u.user_id, u.full_name
ORDER BY spending_rank;


-- Q36: Rank menu items by price within each restaurant
-- PARTITION BY resets the rank for each restaurant
SELECT
    r.name      AS restaurant_name,
    m.name      AS item_name,
    m.price,
    RANK() OVER (
        PARTITION BY m.restaurant_id
        ORDER BY m.price DESC
    )           AS price_rank
FROM menu_item m
JOIN restaurant r ON r.restaurant_id = m.restaurant_id
ORDER BY r.name, price_rank;


-- Q37: Running total of revenue over time
-- SUM() OVER with ORDER BY gives cumulative sum
SELECT
    DATE(placed_at)                                     AS order_date,
    SUM(total_amount)                                   AS daily_revenue,
    SUM(SUM(total_amount)) OVER (ORDER BY DATE(placed_at)) AS running_total
FROM "order"
WHERE status = 'delivered'
GROUP BY DATE(placed_at)
ORDER BY order_date;


-- Q38: For each order, show the customer's order number
-- ROW_NUMBER() counts each customer's orders chronologically
SELECT
    o.order_id,
    u.full_name,
    o.placed_at,
    o.total_amount,
    ROW_NUMBER() OVER (
        PARTITION BY o.user_id
        ORDER BY o.placed_at
    ) AS customers_order_number
FROM "order" o
JOIN "user" u ON u.user_id = o.user_id
ORDER BY u.full_name, customers_order_number;


-- Q39: Compare each restaurant's revenue to the average revenue
-- AVG() OVER() without PARTITION gives global average
SELECT
    r.name                          AS restaurant_name,
    SUM(o.total_amount)             AS restaurant_revenue,
    ROUND(AVG(SUM(o.total_amount)) OVER (), 2) AS avg_revenue_all_restaurants,
    ROUND(SUM(o.total_amount) - AVG(SUM(o.total_amount)) OVER (), 2) AS diff_from_avg
FROM restaurant r
JOIN "order" o ON o.restaurant_id = r.restaurant_id
WHERE o.status = 'delivered'
GROUP BY r.restaurant_id, r.name
ORDER BY restaurant_revenue DESC;


-- Q40: Show each delivery person's deliveries with
-- their personal running count
SELECT
    u.full_name         AS delivery_person,
    d.delivery_id,
    d.delivered_at,
    ROW_NUMBER() OVER (
        PARTITION BY d.dp_user_id
        ORDER BY d.delivered_at
    )                   AS delivery_number
FROM delivery d
JOIN "user" u ON u.user_id = d.dp_user_id
WHERE d.status = 'delivered'
ORDER BY u.full_name, delivery_number;


-- ============================================================
-- END OF QUERIES
-- ============================================================
