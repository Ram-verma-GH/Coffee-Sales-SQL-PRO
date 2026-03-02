-- Monday Coffee SCHEMAS

DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS city;

-- Import 
CREATE TABLE city
(
	city_id	INT PRIMARY KEY,
	city_name VARCHAR(15),	
	population	BIGINT,
	estimated_rent	FLOAT,
	city_rank INT
);

CREATE TABLE customers
(
	customer_id INT PRIMARY KEY,	
	customer_name VARCHAR(25),	
	city_id INT,
	CONSTRAINT fk_city FOREIGN KEY (city_id) REFERENCES city(city_id)
);


CREATE TABLE products
(
	product_id	INT PRIMARY KEY,
	product_name VARCHAR(35),	
	Price float
);


CREATE TABLE sales
(
	sale_id	INT PRIMARY KEY,
	sale_date	date,
	product_id	INT,
	customer_id	INT,
	total FLOAT,
	rating INT,
	CONSTRAINT fk_products FOREIGN KEY (product_id) REFERENCES products(product_id),
	CONSTRAINT fk_customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id) 
);

-- END of SCHEMAS

select * from city
select * from customers
select * from products
select * from sales

-- Q1. How many people in each city are estimated to consume coffee, given that 25% of the population does?

Select city_name, 
Round((population * 0.25)/1000000,2) coffee_consumers_in_millions,
city_rank
from city 
order by 2 desc

-- Q2. What is the total revenue generated from coffee sales across all cities
--	   in the last quarter of 2023?

select 
	sum(total) as total_revenue 
	from sales
where sales.sale_date between '2023-09-01' and '2023-12-31' 
-- OR
SELECT 
	SUM(total) as total_revenue
FROM sales
WHERE 
	EXTRACT(YEAR FROM sale_date)  = 2023
	AND
	EXTRACT(quarter FROM sale_date) = 4
	
-- Q.3
-- Sales Count for Each Product
-- How many units of each coffee product have been sold?

Select p.product_id, p.product_name, count(s.product_id) as total_sale
from products p
join sales s on s.product_id = p.product_id
group by 1
order by 3 desc;
--OR
SELECT 
	p.product_name,
	COUNT(s.sale_id) as total_orders
FROM products as p
LEFT JOIN
sales as s
ON s.product_id = p.product_id
GROUP BY 1
ORDER BY 2 DESC

-- Q.4
-- Average Sales Amount per City
-- What is the average sales amount per customer in each city?

-- city abd total sale
-- no cx in each these city

Select 
ct.city_name, sum(s.total) as total_revenue,
count(distinct c.customer_id) as Total_customers,
round(
	sum(s.total::numeric) / count(distinct s.customer_id)
	,2) As Avg_sale_per_customer
from sales s
JOIN customers c 
    ON s.customer_id = c.customer_id
JOIN city ct 
    ON ct.city_id = c.city_id
group by 1
order by 2 desc

-- -- Q.5
-- City Population and Coffee Consumers (25%)
-- Provide a list of cities along with their populations and estimated coffee consumers.
-- return city_name, total current cx, estimated coffee consumers (25%)

with ct_table as(
Select city_name,
round((population * 0.25) / 1000000,2) as Coffee_customers
From city)
,
customer_table as (
select 
ct.city_name, 
count(distinct c.customer_id) as unique_customer
From city ct
JOIN customers as c
	ON ct.city_id = c.city_id
	group by 1
)
Select ct_table.city_name as City,
ct_table.Coffee_customers as Consumers,
customer_table.unique_customer as unique_customer
from ct_table
join customer_table on customer_table.city_name = ct_table.city_name;

-- -- Q6
-- Top Selling Products by City
-- What are the top 3 selling products in each city based on sales volume?

Select * from (
	Select ct.city_name, p.product_name,
	count(s.product_id) as total_orders,
dense_rank() over (Partition By ct.city_name Order By count(s.product_id) Desc) AS Ranks
	From sales s
	JOIN products as p
	ON s.product_id = p.product_id
	JOIN customers as c
	ON c.customer_id = s.customer_id
	JOIN city as ct
	ON ct.city_id = c.city_id
Group by 1,2
) as Tables
where ranks <= 3;

-- Q.7
-- Customer Segmentation by City
-- How many unique customers are there in each city who have purchased coffee products?

Select ct.city_name, count(distinct c.customer_id) as total_customers
from city ct
left join customers c on c.city_id = ct.city_id
Group by 1;

-- -- Q.8
-- Average Sale vs Rent
-- Find each city and their average sale per customer and avg rent per customer


select * from city
select * from customers
select * from products
select * from sales

with avg_cust as(
	Select ct.city_name, 
	sum(s.total) as Total_sale,
	count(s.customer_id) as Total_cust,
	Round(
	sum(s.total) ::numeric /
	count(s.customer_id) ,2)
	As avg_sale_cust
	FROM sales as s
	JOIN customers as c
	ON s.customer_id = c.customer_id
	JOIN city as ct
	ON ct.city_id = c.city_id
	Group by 1
	Order By 2 desc
),
avg_rent as (
	Select city_name,
	estimated_rent 
	from city
)
Select ac.city_name,
	ar.estimated_rent,
	ac.total_cust,
	ac.avg_sale_cust,
	Round(ar.estimated_rent ::Numeric / ac.total_cust,2) As Avg_rents
	From avg_cust ac
Join avg_rent ar on ac.city_name = ar.city_name
Order By 4 Desc;

-- Q.9
-- Monthly Sales Growth
-- Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly)
-- by each city

with monthly_sale As(
Select ct.city_name,
Extract(Month from s.sale_date) As Month,
Extract(Year from s.sale_date) As Year,
sum(s.total) As Total_sale
From sales s
JOIN customers as c
	ON s.customer_id = c.customer_id
	JOIN city as ct
	ON ct.city_id = c.city_id
Group By 1,2,3
),
growth_rate As(
	Select city_name,
	Month, Year,
	Total_sale as Cr_monthSale,
	Lag(Total_sale,1) over (Partition By city_name Order By Year,Month) As Prev_sale
	From monthly_sale)

Select city_name,
	Month, Year,
	Cr_monthSale,
	Prev_sale,
	Round(
	(cr_monthSale - Prev_sale) :: Numeric / Prev_sale ::Numeric * 100,2)As Ratio
	From growth_rate
Where prev_sale is not null;

-- Q.10
-- Market Potential Analysis
-- Identify top 3 city based on highest sales, return city name, 
-- total sale, total rent, total customers, estimated coffee consumer

With city_table As(
	Select ct.city_name,
	Sum(s.total) As total_revanue,
	count(s.customer_id) As total_customer,
	Round(sum(s.total) :: Numeric / count(distinct c.customer_id),2) As AvgSale_PerCust
	From sales s
JOIN customers as c
	ON s.customer_id = c.customer_id
	JOIN city as ct
	ON ct.city_id = c.city_id
	GROUP BY 1
	ORDER BY 2 DESC
),
Rent_table As(
Select city_name,
	estimated_rent,
	round(population * 0.25 / 1000000 ,3) As est_Coffee_consumer
	From city
)
Select rt.city_name,
	ct.total_revanue,
	ct.AvgSale_PerCust,
	ct.total_customer,
	rt.estimated_rent,
	rt.est_Coffee_consumer,
	Round(rt.estimated_rent :: Numeric / ct.total_customer,2) As Avg_rent_PerCust 
	From city_table ct
	join rent_table rt on rt.city_name = ct.city_name
	order by 2;