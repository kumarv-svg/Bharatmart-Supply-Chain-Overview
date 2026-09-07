USE bharatmart_supply_chain;

-- What are the total orders, total order value, and average order value?
SELECT COUNT(DISTINCT order_ID) AS total_orders,
SUM(Total_Order_Value) AS total_order_value,
AVG(Total_Order_Value) AS avg_order_value
FROM orders;

-- How many orders were placed each month?
SELECT DATE_FORMAT(Order_Date, "%Y-%m") as month_year,
COUNT(DISTINCT Order_ID) AS total_orders
FROM orders
GROUP BY month_year;

-- Which customers have placed more than 5 orders?
SELECT Customer_ID AS Customers, COUNT(DISTINCT Order_ID) AS total_orders
FROM orders
GROUP BY Customer_ID
HAVING total_orders>5;

-- What are the top 10 customers by total order value?
SELECT Customer_ID AS Customers, SUM(Total_Order_Value) as order_value
FROM orders
GROUP BY Customer_ID
ORDER BY order_value DESC
LIMIT 10;

-- Which products have the highest total quantity ordered?
SELECT Product_ID AS products, SUM(Quantity_Ordered) AS total_quantity
FROM order_items
GROUP BY Product_ID
ORDER BY total_quantity DESC;

-- Which regions generate the highest order value?
SELECT Region, SUM(Total_Order_Value) AS order_value
FROM orders
GROUP BY Region
ORDER BY order_value DESC
LIMIT 1;

-- What is the order fulfillment rate for each product?
SELECT Product_ID, 
SUM(Allocated_Quantity)/SUM(Quantity_Ordered) * 100 AS fulfillment_rate
FROM order_items
GROUP BY Product_ID
ORDER BY fulfillment_rate DESC;

-- Which suppliers have the highest purchase order value?
SELECT s.Supplier_ID AS supplier_name, SUM(po.PO_Value) AS purchase_value
FROM suppliers s
JOIN purchase_orders po
	ON po.Supplier_ID = s.Supplier_ID
GROUP BY s.Supplier_ID
ORDER BY purchase_value DESC;

-- Which suppliers have the worst on-time delivery performance?
SELECT Supplier_ID, (SUM(ON_Flag) / COUNT(*))*100 as worst_delivery_performance
FROM purchase_orders
GROUP BY Supplier_ID
ORDER BY worst_delivery_performance ASC;

-- Which warehouses have the highest inventory value?
SELECT i.Warehouse_ID, w.Warehouse_Name, SUM(i.Inventory_Value) as inventory_value
FROM inventory i
JOIN warehouses w
	ON w.Warehouse_ID = i.Warehouse_ID
GROUP BY i.Warehouse_ID, w.Warehouse_Name
ORDER BY inventory_value DESC;

-- What is BharatMart's overall OTIF percentage?
SELECT (SUM(OTIF_Flag)/COUNT(*))*100 AS OTIF_per
FROM shipments;

-- What is the fill rate for each warehouse?
SELECT Warehouse_ID,
SUM(Quantity_Delivered)/SUM(Quantity_Ordered)*100 AS fill_rate
FROM shipments
GROUP BY Warehouse_ID
ORDER BY fill_rate DESC;

-- Which carriers have the highest delay and damage rates?
SELECT s.Carrier_ID, c.Carrier_Name,
ROUND(((SUM(CASE WHEN s.Delay_Days>0 THEN 1 ELSE 0 END)/COUNT(*))*100), 1) AS delay_rate, 
ROUND(((SUM(s.Damage_Quantity)/SUM(s.Quantity_Delivered))*100), 2) AS damage_rate
FROM shipments s
JOIN carriers c
	ON c.Carrier_ID = s.Carrier_ID
GROUP BY s.Carrier_ID, c.Carrier_Name
ORDER BY delay_rate DESC, damage_rate DESC;

-- Which products are currently at risk of stockout?
SELECT Product_ID, 
ROUND(((SUM(CASE WHEN Stockout_Flag="Yes" THEN 1 ELSE 0 END)/COUNT(*))*100), 2) AS stockout_rate
FROM inventory
GROUP BY Product_ID
HAVING stockout_rate>0
ORDER BY stockout_rate DESC;

-- Which suppliers contribute the most to total supply-chain delays?
SELECT Supplier_ID, SUM(Delay_Days) AS total_delay_days,
ROUND(SUM(Delay_Days) / (SELECT SUM(Delay_Days) FROM purchase_orders) * 100, 2) AS delay_contribution_pct
FROM purchase_orders
GROUP BY Supplier_ID
ORDER BY delay_contribution_pct DESC;

-- What are the top 3 suppliers in each region based on on-time delivery percentage?
WITH supplier_data AS (
	SELECT s.Supplier_ID, s.Supplier_Name, s.Region,
	ROUND(((SUM(p.ON_Flag)/COUNT(*))* 100), 2) AS on_time_delivery_per
	FROM purchase_orders p
	JOIN suppliers s
		ON s.Supplier_ID = p.Supplier_ID
	GROUP BY s.Supplier_ID, s.Supplier_Name, s.Region
),
ranked_suppliers AS (
	SELECT Region, Supplier_ID, Supplier_Name, on_time_delivery_per, 
    DENSE_RANK() OVER(PARTITION BY Region ORDER BY on_time_delivery_per DESC) AS supplier_rank
    FROM supplier_data
)
SELECT supplier_rank, Region, Supplier_ID, Supplier_Name, on_time_delivery_per
FROM ranked_suppliers
WHERE supplier_rank<=3
ORDER BY Region, supplier_rank;

-- What are the top 3 products in each category based on total quantity ordered?
WITH category AS (
	SELECT oi.Product_ID AS product_ID, p.Category AS categories, SUM(oi.Quantity_Ordered) AS ordered_quantity
    FROM order_items oi
    JOIN products p
		ON p.Product_ID = oi.Product_ID
	GROUP BY oi.Product_ID, p.Category
),
category_rank AS (
	SELECT product_ID, categories, ordered_quantity, 
    DENSE_RANK() OVER(PARTITION BY categories ORDER BY ordered_quantity DESC) AS rank_order
    FROM category
)
SELECT rank_order, categories, product_ID, ordered_quantity
FROM category_rank
WHERE rank_order<=3
ORDER BY categories, rank_order;

-- Which warehouses have an OTIF percentage below the overall company OTIF percentage?
WITH otif AS (
	SELECT w.Warehouse_ID, w.Warehouse_Name,
	ROUND(((SUM(s.OTIF_Flag)/COUNT(*))*100), 2) AS otif_per
	FROM warehouses w
	JOIN shipments s
		ON s.Warehouse_ID = w.Warehouse_ID
	GROUP BY w.Warehouse_ID, w.Warehouse_Name
)
SELECT Warehouse_ID, Warehouse_Name, otif_per
FROM otif
WHERE otif_per < (
	SELECT ROUND((SUM(OTIF_Flag)/COUNT(*)* 100),2)
    FROM shipments
)
ORDER BY otif_per;

-- Which 10 customers are most affected by delivery delays?
SELECT c.Customer_ID, c.Customer_Name, SUM(s.Delay_Days) AS delay_days
FROM customers c
JOIN orders o
	ON o.Customer_ID = c.Customer_ID
JOIN shipments s
	ON s.Order_ID = o.Order_ID
GROUP BY c.Customer_ID, c.Customer_Name
ORDER BY delay_days DESC
LIMIT 10;

