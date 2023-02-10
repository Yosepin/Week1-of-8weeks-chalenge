use dannys_diner;
select * from members;
select * from menu;
select * from sales;

-- 1. What is the total amount each customer spent at the restaurant?
SELECT  customer_id,
		SUM(price) spent_money
FROM sales 
JOIN menu ON sales.product_id = menu.product_id
GROUP BY 1;

-- 2. How many days has each customer visited the restaurant?
SELECT customer_id,
		count(distinct order_date) visit_count
FROM sales
GROUP BY 1;

-- 3. What was the first item from the menu purchased by each customer?
WITH table_temp AS(
SELECT 	s.customer_id, 
		s.product_id,
		DENSE_RANK() OVER(partition by s.customer_id order by s.order_date asc) as rnk,
        m.product_name
FROM sales s
JOIN menu m On s.product_id = m.product_id)
SELECT customer_id,
		product_name
FROM table_temp
WHERE rnk = 1
GROUP BY 1,2;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT  COUNT(s.product_id) amount_purchased,
		m.product_name
FROM sales s
JOIN menu m on s.product_id = m.product_id
GROUP BY 2
ORDER BY 1 DESC
LIMIT 1;

-- 5. Which item was the most popular for each customer?
WITH table2 AS 
(
SELECT  customer_id,
		product_name,
        COUNT(s.product_id) amount_order,
        dense_rank() Over(partition by customer_id order by  COUNT(s.product_id) desc) rnk
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY 1,2
)
SELECT * FROM table2
WHERE rnk = 1;

-- 6. Which item was purchased first by the customer after they became a member?
WITH table_temp AS(
SELECT 	s.customer_id, 
		s.product_id,
        s.order_date,
        me.join_date,
		DENSE_RANK() OVER(partition by s.customer_id order by s.order_date asc) as rnk,
        m.product_name
FROM sales s
JOIN menu m On s.product_id = m.product_id
JOIN members me on me.customer_id = s.customer_id
WHERE join_date < order_date)
SELECT customer_id,
		product_name
FROM table_temp
WHERE rnk = 1 
GROUP BY 1,2;

-- 7. Which item was purchased just before the customer became a member?
WITH table_temp AS(
SELECT 	s.customer_id, 
		s.product_id,
        s.order_date,
        me.join_date,
		DENSE_RANK() OVER(partition by s.customer_id order by s.order_date asc) as rnk,
        m.product_name
FROM sales s
JOIN menu m On s.product_id = m.product_id
JOIN members me on me.customer_id = s.customer_id
WHERE join_date > order_date)
SELECT customer_id,
		product_name
FROM table_temp
WHERE rnk = 1 
GROUP BY 1,2;

-- 8. What is the total items and amount spent for each member before they became a member?
WITH table3 AS
(
SELECT  s.customer_id,
		product_id,
		COUNT(s.product_id) total_item,
        CASE 
				WHEN product_id = 1 AND s.customer_id = 'A' then COUNT(s.product_id)*10
				WHEN product_id = 2 AND s.customer_id = 'A' then COUNT(s.product_id)*15
				WHEN product_id = 1 AND s.customer_id = 'B' then COUNT(s.product_id)*10
				WHEN product_id = 2 AND s.customer_id = 'B' then COUNT(s.product_id)*15
		END spent_money
FROM sales s
JOIN members me on s.customer_id = me.customer_id
WHERE s.order_date < me.join_date 
GROUP BY 1,2
)
SELECT customer_id,
		SUM(total_item) total_item,
        sum(spent_money) total_spent_money
FROM table3
GROUP BY 1;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH table4 AS
(
SELECT  s.customer_id,
		s.product_id,
        m.product_name,
		COUNT(s.product_id) total_item,
        CASE 
				WHEN s.product_id = 1 AND s.customer_id = 'A' then COUNT(s.product_id)*10
				WHEN s.product_id = 2 AND s.customer_id = 'A' then COUNT(s.product_id)*15
                WHEN s.product_id = 3 AND s.customer_id = 'A' then COUNT(s.product_id)*12
				WHEN s.product_id = 1 AND s.customer_id = 'B' then COUNT(s.product_id)*10
				WHEN s.product_id = 2 AND s.customer_id = 'B' then COUNT(s.product_id)*15
                WHEN s.product_id = 3 AND s.customer_id = 'B' then COUNT(s.product_id)*12
                WHEN s.product_id = 1 AND s.customer_id = 'C' then COUNT(s.product_id)*10
				WHEN s.product_id = 2 AND s.customer_id = 'C' then COUNT(s.product_id)*15
                WHEN s.product_id = 3 AND s.customer_id = 'C' then COUNT(s.product_id)*12
		END spent_money
FROM sales s
JOIN menu m on s.product_id = m.product_id
GROUP BY 1,2,3
)
SELECT  customer_id,
		SUM(CASE
				WHEN product_name = 'sushi' then spent_money*10*2
				ELSE spent_money*10
			END) points
FROM table4
GROUP BY 1;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
-- not just sushi - how many points do customer A and B have at the end of January?
WITH dates_cte AS 
(
SELECT  *,
		adddate(join_date, interval 7 day) valid_date,
        '2021-01-31' last_date
 FROM members m
)
SELECT 	d.customer_id,
		s.order_date, 
		d.join_date, 
		d.valid_date, 
        d.last_date, 
        m.product_name, 
        m.price,
		SUM(CASE
				WHEN m.product_name = 'sushi' THEN 2 * 10 * m.price
				WHEN s.order_date BETWEEN d.join_date AND d.valid_date THEN 2 * 10 * m.price
				ELSE 10 * m.price
			END) points
FROM dates_cte AS d
JOIN sales s USING (customer_id)
JOIN menu m USING (product_id)
WHERE s.order_date < d.last_date
GROUP BY d.customer_id, s.order_date, d.join_date, d.valid_date, d.last_date, m.product_name, m.price
ORDER BY 1;

-- 11
SELECT  s.customer_id,
		s.order_date,
        m.product_name,
        m.price,
        CASE
			WHEN me.join_date > s.order_date THEN 'N'
			WHEN me.join_date <= s.order_date THEN 'Y'
			ELSE 'N'
		END AS member
FROM sales s
LEFT JOIN menu m ON s.product_id = m.product_id
LEFT JOIN members me ON s.customer_id = me.customer_id;

WITH table5 AS
(
SELECT  s.customer_id,
		s.order_date,
        m.product_name,
        m.price,
        CASE
			WHEN me.join_date > s.order_date THEN 'N'
			WHEN me.join_date <= s.order_date THEN 'Y'
			ELSE 'N'
		END AS member
FROM sales s
LEFT JOIN menu m ON s.product_id = m.product_id
LEFT JOIN members me ON s.customer_id = me.customer_id
)
SELECT *, CASE
			WHEN member = 'N' THEN null
			ELSE DENSE_RANK() OVER(PARTITION BY customer_id, member ORDER BY order_date ASC)
		END ranking
FROM table5;
