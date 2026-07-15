DROP TABLE IF EXISTS bronze.orders;
CREATE TABLE bronze.orders (
    row_id INT,
    order_id VARCHAR(50),
    order_date DATE,
    ship_date DATE,
    ship_mode VARCHAR(50),
    customer_id VARCHAR(50),
    customer_name VARCHAR(100),
    segment VARCHAR(50),
    country_region VARCHAR(50),
    city VARCHAR(100),
    state VARCHAR(50),
    postal_code VARCHAR(50),
    region VARCHAR(50),
    product_id VARCHAR(50),
    category VARCHAR(50),
    sub_category VARCHAR(50),
    product_name VARCHAR(255),
    sales DECIMAL(10,4),
    quantity INT,
    discount DECIMAL(5,4),
    profit DECIMAL(10,4)
);

DROP TABLE IF EXISTS bronze.people;
CREATE TABLE bronze.people (
    person_name VARCHAR(50),
    region VARCHAR(50)
);


DROP TABLE IF EXISTS bronze.returns_order;
CREATE TABLE bronze.returns_order (
    returned VARCHAR(3),
    order_id VARCHAR(20)
);