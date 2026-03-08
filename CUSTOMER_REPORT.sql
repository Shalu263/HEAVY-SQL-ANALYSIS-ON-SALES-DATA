/*
================================================================================================================
Customer Report
================================================================================================================

Purpose:
    - This report consolidates key customer metrics and behaviors

Highlights:
    1. Gathers essential fields such as names, ages, and transaction details.
    2. Segments customers into categories (VIP, Regular, New) and age groups.
    3. Aggregates customer-level metrics:
        - total orders
        - total sales
        - total quantity purchased
        - total products
        - lifespan (in months)
    4. Calculates valuable KPIs:
        - recency (months since last order)
        - average order value
        - average monthly spend
*/
---1. RETRIEVE ALL THE COLUMNS FROM FACT TABLE:--

CREATE VIEW dbo.report_customer AS
WITH base_query AS(
SELECT 
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
c.first_name,
c.last_name,
CONCAT(c.first_name,' ',c.last_name) AS customer_name,
c.birthdate,
DATEDIFF(year,c.birthdate,GETDATE()) age
FROM dbo.fact_sales f
LEFT JOIN dbo.dim_customers c
ON c.customer_key=f.customer_key
WHERE order_date is not null
)
--SELECT * FROM base_query

-------------------------------
 ----AGGREGATIONS---
-------------------------------

,Customer_aggregations AS(          
SELECT 
     customer_key,
     customer_name,
     customer_number,
     age,
     COUNT(DISTINCT order_number) AS total_orders,
     SUM(sales_amount) AS total_sales,
     SUM(quantity) AS total_quantity,
     COUNT(DISTINCT product_key) AS total_products,
     MAX(order_date) AS last_order_date,
     DATEDIFF(month,MIN(order_date),MAX(order_date)) AS lifespan
FROM base_query
GROUP BY
       customer_key,
       customer_name,
       customer_number,
       age)
--SELECT * 
--FROM Customer_aggregations;

-------------------------------------------
--SEGMENTS CUSTOMERS INTO CATEGORIES--
-------------------------------------------
SELECT
       customer_key,
       customer_name,
       customer_number,
       age,
       CASE WHEN age<20 THEN 'under20'
            WHEN age BETWEEN 20 AND 29 then '20-29'
            WHEN age BETWEEN 30 AND 39 then '30-39'
            WHEN age BETWEEN 40 AND 49 then '40-49'
       ELSE '50 and above'
       END as age_group,
       CASE 
           WHEN lifespan>=12 AND total_sales>5000 THEN 'VIP'
           WHEN lifespan>=12 AND total_sales<=5000 THEN 'Regular'
           ELSE 'New'
       END as customer_segment,
       last_order_date,
       DATEDIFF(month,last_order_date,GETDATE()) as recency,
       total_orders,
       total_sales,
       total_quantity,
       total_products,
       lifespan,

--------- COMPUTE AVG ORDER VALUE----(AVO)
CASE WHEN total_orders =0 then '0'
ELSE total_sales/total_orders 
END as average_order_value,
--------- COMPUTE AVG MONTHLY SPEND---
CASE WHEN lifespan=0 then total_sales
ELSE total_sales/lifespan 
END AS avg_monthly_spend
FROM 
Customer_aggregations;


 -------REPORT----
 SELECT 
 *
 FROM dbo.report_customer
