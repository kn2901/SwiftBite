-- ============================================================
--  FOOD DELIVERY SYSTEM
--  DDL Script — PostgreSQL
-- ============================================================


-- ============================================================
-- STEP 1: CREATE ENUM TYPES
-- Enums restrict a column to specific allowed values only.
-- ============================================================

CREATE TYPE user_role AS ENUM ('customer', 'delivery_person', 'admin');

CREATE TYPE dp_status AS ENUM ('available', 'busy', 'offline');

CREATE TYPE order_status AS ENUM (
    'placed', 'confirmed', 'preparing',
    'out_for_delivery', 'delivered', 'cancelled'
);

CREATE TYPE delivery_status AS ENUM ('assigned', 'picked_up', 'delivered');

CREATE TYPE payment_method AS ENUM ('cash', 'card', 'upi', 'wallet');

CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded');


-- ============================================================
-- STEP 2: CREATE TABLES
-- Order matters — a table must exist before another
-- table can reference it with a FOREIGN KEY.
-- ============================================================


-- ------------------------------------------------------------
-- TABLE 1: user
-- Stores all users — customers, delivery persons, and admins.
-- role column tells us what type of user this is.
-- ------------------------------------------------------------
CREATE TABLE "user" (
    user_id       SERIAL        PRIMARY KEY,
    email         VARCHAR(120)  NOT NULL UNIQUE,
    password_hash VARCHAR(255)  NOT NULL,
    full_name     VARCHAR(100)  NOT NULL,
    phone         VARCHAR(15)   UNIQUE,
    role          user_role     NOT NULL,
    created_at    TIMESTAMP     DEFAULT NOW(),

    CHECK (email LIKE '%@%.%'),
    CHECK (phone IS NULL OR LENGTH(phone) BETWEEN 7 AND 15)
);


-- ------------------------------------------------------------
-- TABLE 2: user_address
-- A customer can have multiple saved addresses.
-- Delivery persons have no rows in this table.
-- This table exists because address is a multivalued attribute.
-- ------------------------------------------------------------
CREATE TABLE user_address (
    address_id  SERIAL       PRIMARY KEY,
    user_id     INT          NOT NULL,
    label       VARCHAR(50),
    address     TEXT         NOT NULL,
    is_default  BOOLEAN      DEFAULT FALSE,

    FOREIGN KEY (user_id) REFERENCES "user"(user_id) ON DELETE CASCADE,
    UNIQUE (user_id, label)
);


-- ------------------------------------------------------------
-- TABLE 3: delivery_person
-- Extra info for users who are delivery persons.
-- user_id is both PRIMARY KEY and FOREIGN KEY (shared PK pattern).
-- This enforces the 1:1 relationship with user table.
-- ------------------------------------------------------------
CREATE TABLE delivery_person (
    user_id  INT         PRIMARY KEY,
    status   dp_status   NOT NULL DEFAULT 'offline',
    rating   DECIMAL(3,2),

    FOREIGN KEY (user_id) REFERENCES "user"(user_id) ON DELETE RESTRICT,
    CHECK (rating IS NULL OR rating BETWEEN 0.0 AND 5.0)
);


-- ------------------------------------------------------------
-- TABLE 4: restaurant
-- ------------------------------------------------------------
CREATE TABLE restaurant (
    restaurant_id  SERIAL        PRIMARY KEY,
    name           VARCHAR(100)  NOT NULL,
    address        TEXT          NOT NULL,
    phone          VARCHAR(15)   UNIQUE,
    is_open        BOOLEAN       DEFAULT FALSE,
    rating         DECIMAL(3,2),
    open_time      TIME,
    close_time     TIME,

    CHECK (rating IS NULL OR rating BETWEEN 0.0 AND 5.0),
    CHECK (open_time IS NULL OR close_time IS NULL OR close_time > open_time)
);


-- ------------------------------------------------------------
-- TABLE 5: category
-- Global categories like Biryani, Pizza, Burger.
-- Not tied to any specific restaurant here.
-- The link to restaurant is in restaurant_category table.
-- ------------------------------------------------------------
CREATE TABLE category (
    category_id  SERIAL       PRIMARY KEY,
    name         VARCHAR(80)  NOT NULL UNIQUE
);


-- ------------------------------------------------------------
-- TABLE 6: restaurant_category
-- Junction table — resolves the M:N relationship between
-- restaurant and category.
-- A restaurant can have many categories.
-- A category can belong to many restaurants.
-- ------------------------------------------------------------
CREATE TABLE restaurant_category (
    restaurant_id  INT  NOT NULL,
    category_id    INT  NOT NULL,

    PRIMARY KEY (restaurant_id, category_id),
    FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id)   REFERENCES category(category_id)     ON DELETE RESTRICT
);


-- ------------------------------------------------------------
-- TABLE 7: menu_item
-- Each item belongs to one restaurant.
-- category_id is nullable — item can be uncategorized.
-- price must always be greater than 0.
-- ------------------------------------------------------------
CREATE TABLE menu_item (
    item_id        SERIAL         PRIMARY KEY,
    restaurant_id  INT            NOT NULL,
    category_id    INT,
    name           VARCHAR(100)   NOT NULL,
    description    TEXT,
    price          DECIMAL(8,2)   NOT NULL,
    is_available   BOOLEAN        DEFAULT TRUE,

    FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id) ON DELETE RESTRICT,
    FOREIGN KEY (category_id)   REFERENCES category(category_id)     ON DELETE SET NULL,
    CHECK (price > 0)
);


-- ------------------------------------------------------------
-- TABLE 8: cart
-- One cart per customer per restaurant.
-- UNIQUE(user_id, restaurant_id) ensures this.
-- ------------------------------------------------------------
CREATE TABLE cart (
    cart_id        SERIAL     PRIMARY KEY,
    user_id        INT        NOT NULL,
    restaurant_id  INT        NOT NULL,
    updated_at     TIMESTAMP  DEFAULT NOW(),

    FOREIGN KEY (user_id)       REFERENCES "user"(user_id)           ON DELETE CASCADE,
    FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id) ON DELETE CASCADE,
    UNIQUE (user_id, restaurant_id)
);


-- ------------------------------------------------------------
-- TABLE 9: cart_item
-- Weak entity — cannot exist without a cart.
-- Composite PK (cart_id, item_id) prevents same item
-- from being added twice to the same cart.
-- unit_price is stored here (frozen at time of adding).
-- ------------------------------------------------------------
CREATE TABLE cart_item (
    cart_id     INT           NOT NULL,
    item_id     INT           NOT NULL,
    quantity    INT           NOT NULL,
    unit_price  DECIMAL(8,2)  NOT NULL,

    PRIMARY KEY (cart_id, item_id),
    FOREIGN KEY (cart_id) REFERENCES cart(cart_id)          ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES menu_item(item_id)     ON DELETE RESTRICT,
    CHECK (quantity   > 0),
    CHECK (unit_price > 0)
);


-- ------------------------------------------------------------
-- TABLE 10: order
-- "order" is a reserved word in SQL so we quote it.
-- delivery_address is copied from user_address at order time.
-- total_amount is stored directly (materialized value).
-- ------------------------------------------------------------
CREATE TABLE "order" (
    order_id          SERIAL          PRIMARY KEY,
    user_id           INT             NOT NULL,
    restaurant_id     INT             NOT NULL,
    delivery_address  TEXT            NOT NULL,
    total_amount      DECIMAL(10,2)   NOT NULL,
    delivery_fee      DECIMAL(6,2)    DEFAULT 0,
    status            order_status    DEFAULT 'placed',
    placed_at         TIMESTAMP       DEFAULT NOW(),
    delivered_at      TIMESTAMP,

    FOREIGN KEY (user_id)       REFERENCES "user"(user_id)           ON DELETE RESTRICT,
    FOREIGN KEY (restaurant_id) REFERENCES restaurant(restaurant_id) ON DELETE RESTRICT,
    CHECK (total_amount > 0),
    CHECK (delivery_fee >= 0),
    CHECK (delivered_at IS NULL OR delivered_at >= placed_at)
);


-- ------------------------------------------------------------
-- TABLE 11: order_item
-- Weak entity — cannot exist without an order.
-- Composite PK (order_id, item_id).
-- unit_price frozen at order time — historical record.
-- ------------------------------------------------------------
CREATE TABLE order_item (
    order_id    INT            NOT NULL,
    item_id     INT            NOT NULL,
    quantity    INT            NOT NULL,
    unit_price  DECIMAL(8,2)   NOT NULL,

    PRIMARY KEY (order_id, item_id),
    FOREIGN KEY (order_id) REFERENCES "order"(order_id)     ON DELETE CASCADE,
    FOREIGN KEY (item_id)  REFERENCES menu_item(item_id)    ON DELETE RESTRICT,
    CHECK (quantity   > 0),
    CHECK (unit_price > 0)
);


-- ------------------------------------------------------------
-- TABLE 12: delivery
-- Created after order is confirmed.
-- UNIQUE(order_id) enforces the 1:1 with order.
-- Timestamps must be in order: assigned → picked → delivered.
-- ------------------------------------------------------------
CREATE TABLE delivery (
    delivery_id   SERIAL           PRIMARY KEY,
    order_id      INT              NOT NULL UNIQUE,
    dp_user_id    INT              NOT NULL,
    status        delivery_status  DEFAULT 'assigned',
    assigned_at   TIMESTAMP        DEFAULT NOW(),
    picked_at     TIMESTAMP,
    delivered_at  TIMESTAMP,

    FOREIGN KEY (order_id)   REFERENCES "order"(order_id)          ON DELETE RESTRICT,
    FOREIGN KEY (dp_user_id) REFERENCES delivery_person(user_id)   ON DELETE RESTRICT,
    CHECK (picked_at    IS NULL OR picked_at    >= assigned_at),
    CHECK (delivered_at IS NULL OR delivered_at >= picked_at)
);


-- ------------------------------------------------------------
-- TABLE 13: payment
-- 1:N with order — multiple payment attempts allowed.
-- transaction_id is UNIQUE but nullable
-- (NULL for cash payments or failed/pending attempts).
-- ------------------------------------------------------------
CREATE TABLE payment (
    payment_id      SERIAL          PRIMARY KEY,
    order_id        INT             NOT NULL,
    amount          DECIMAL(10,2)   NOT NULL,
    method          payment_method  NOT NULL,
    status          payment_status  DEFAULT 'pending',
    transaction_id  VARCHAR(100)    UNIQUE,
    paid_at         TIMESTAMP,

    FOREIGN KEY (order_id) REFERENCES "order"(order_id) ON DELETE RESTRICT,
    CHECK (amount > 0)
);


-- ============================================================
-- STEP 3: CREATE INDEXES
-- Indexes speed up queries on columns that are
-- frequently used in WHERE, JOIN, or ORDER BY clauses.
-- PK and UNIQUE columns already have indexes automatically.
-- These are extra indexes for common query patterns.
-- ============================================================

CREATE INDEX ON menu_item   (restaurant_id);
CREATE INDEX ON menu_item   (category_id);
CREATE INDEX ON "order"     (user_id);
CREATE INDEX ON "order"     (restaurant_id);
CREATE INDEX ON "order"     (status);
CREATE INDEX ON delivery    (dp_user_id);
CREATE INDEX ON delivery_person (status);
CREATE INDEX ON payment     (order_id);
CREATE INDEX ON cart        (user_id);


-- ============================================================
-- END OF DDL
-- ============================================================
