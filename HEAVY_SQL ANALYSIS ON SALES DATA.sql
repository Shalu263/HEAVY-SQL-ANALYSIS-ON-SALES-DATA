--CHANGES OVER TIME--

SELECT YEAR(order_date) AS Order_year,
       SUM(sales_amount) AS total_Sales,
       COUNT(DISTINCT customer_key) as total_customers,
       SUM(quantity) as total_quantity
FROM dbo.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date);

 --OR--

SELECT MONTH(order_date) AS Order_month,
       YEAR(order_date) AS Order_year,
       SUM(sales_amount) AS total_Sales,
       COUNT(DISTINCT customer_key) as total_customers,
       SUM(quantity) as total_quantity
FROM dbo.fact_sales
WHERE order_date IS NOT NULL
GROUP BY MONTH(order_date),YEAR(order_date)
ORDER BY MONTH(order_date),YEAR(order_date);

--OR--
SELECT FORMAT(order_date,'yyy-mmm') AS Order_date,
       SUM(sales_amount) AS total_Sales,
       COUNT(DISTINCT customer_key) as total_customers,
       SUM(quantity) as total_quantity
FROM dbo.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date,'yyy-mmm')
ORDER BY FORMAT(order_date,'yyy-mmm');



--CUMULATIVE ANALYSIS--
--TASK: Calculate total sales each month and running sales over time--
SELECT
order_date,
total_sales,
SUM(total_sales) OVER(ORDER BY order_date) AS  running_sales
FROM
(
SELECT
    DATETRUNC(month, order_date) AS order_date,
    SUM(sales_amount) AS total_sales
FROM dbo.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
) t

--by year--
SELECT
order_date,
total_sales,
SUM(total_sales) OVER(ORDER BY order_date) AS  running_sales
FROM
(
SELECT
    DATETRUNC(year, order_date) AS order_date,
    SUM(sales_amount) AS total_sales
FROM dbo.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(year, order_date)
) t

--MOVING AVERAGE--
SELECT
order_date,
total_sales,
SUM(total_sales) OVER(ORDER BY order_date) AS  running_sales,
AVG(avg_price) OVER(ORDER BY order_date) AS moving_avg_price
FROM
(
SELECT
    DATETRUNC(year, order_date) AS order_date,
    SUM(sales_amount) AS total_sales,
    AVG(price) AS avg_price
FROM dbo.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(year, order_date)
) t;


--PERFORMATIVE ANALYSIS-- Comparing current value with the target value. Current-targeted
--TASK:ANALYZE THE YEARLY PERFORMANCE OF PRODUCTS BY COMPARING EACH PRODUCT SALES TO BOTH ITS AVG SALES AND PREVIOUS YEAR SALES.--

WITH yearly_product_sales AS(
SELECT
    YEAR(f.order_date) AS order_year,
    p.product_name,
    SUM(f.sales_amount) AS current_sales
FROM dbo.fact_sales f
LEFT JOIN dbo.dim_products p
    ON f.product_key = p.product_key
WHERE order_date IS NOT NULL
GROUP BY 
YEAR(f.order_date),
p.product_name 
)

SELECT
    order_year,
    product_name,
    current_sales,
    AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
    current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,

    CASE 
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
        ELSE 'Avg'
    END avg_change,

    --- year over year--
    LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS PY_sales,

    current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS diff_PY,

    CASE 
        WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
        WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
        ELSE 'No Change'
    END AS py_change

FROM yearly_product_sales
ORDER BY product_name, order_year


-- PART-TO-WHOLE-ANALYSIS--
--TASK: Which categories contribute the most tooverall sales?--
WITH category_sales AS(
SELECT 
category,
SUM(sales_amount) AS total_sales
FROM dbo.fact_sales f
LEFT JOIN dbo.dim_products p
ON p.product_key=f.product_key
GROUP BY category)

SELECT category,
total_sales,
SUM(total_sales) OVER() overall_sales,
CONCAT(ROUND((CAST(total_sales AS FLOAT)/SUM(total_sales) OVER())*100,2),'%') AS percent_sales
FROM category_sales
ORDER BY total_sales DESC


--DATA SEGMENTATION--
--TASK: Segment products into cost ranges and cound how many products fall into each segment--

WITH product_segments AS(
SELECT product_name, 
product_key,
cost,
CASE 
    WHEN cost<100 THEN 'Below 100'
    WHEN cost BETWEEN 100 and 500 THEN '100-500'
    WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
    ELSE 'Above 1000'
END cost_range
         
FROM dbo.dim_products
)

SELECT 
cost_range,
COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range;

--TASK: Group customers into three segments based on spending behaviour
        -- Also find the number of customers in each group.
WITH customer_spending AS(
SELECT
c.customer_key,
SUM(f.sales_amount) AS total_spending,
MIN(order_date) AS first_order,
MAX(order_date) AS last_order,
DATEDIFF(month,MIN(order_date),MAX(order_date)) AS lifespan
FROM fact_sales f
LEFT JOIN dim_customers c
ON f.customer_key=c.customer_key
GROUP BY c.customer_key
)

--no.of customers--
SELECT 
customer_segment,
COUNT(customer_key) AS total_customers
FROM
(
SELECT 
customer_key,
CASE WHEN lifespan>=12 AND total_spending>5000 THEN 'VIP'
     WHEN lifespan>=12 AND total_spending<=5000 THEN 'Regular'
     ELSE 'New'
END customer_segment
FROM customer_spending) t
GROUP BY customer_segment
ORDER BY total_customers DESC