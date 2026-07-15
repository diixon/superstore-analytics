-- Fact table indexes for common query patterns
CREATE NONCLUSTERED INDEX IX_fact_sales_order_date ON gold.fact_sales(order_date_key);
CREATE NONCLUSTERED INDEX IX_fact_sales_ship_date ON gold.fact_sales(ship_date_key);
CREATE NONCLUSTERED INDEX IX_fact_sales_customer ON gold.fact_sales(customer_key);
CREATE NONCLUSTERED INDEX IX_fact_sales_product ON gold.fact_sales(product_key);
CREATE NONCLUSTERED INDEX IX_fact_sales_location ON gold.fact_sales(location_key);
GO