-- 1) What is the total amount each customer spent at the restaurant?

	SELECT 
		s.customer_id, SUM(m.price) AS total_spent
	FROM
		sales s
			LEFT JOIN
		menu m ON s.product_id = m.product_id
	GROUP BY s.customer_id
	;

-- 2) How many days has each customer visited the restaurant?

	SELECT 
    customer_id, COUNT(DISTINCT order_date) AS order_count
FROM
    sales
GROUP BY customer_id
	;

-- 3) What was the first item from the menu purchased by each customer?

	SELECT customer_id, product_name
	FROM 
							-- subquery as we only want to return specific columns. This also could be done using a CTE 
	(SELECT 
		s.customer_id, 
		s.order_date, 
		m.product_name,
							-- windows function to rank orders. The number restarts when  the column(s) we partition by change.
		ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) order_ranking
	FROM 
		sales s
	JOIN 
		menu m ON s.product_id = m.product_id
	) AS ranked_orders

	WHERE order_ranking = 1 
	;


--  4) What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT 
    m.product_name, COUNT(product_name) AS times_ordered
FROM
    sales s
        LEFT JOIN
    menu m ON s.product_id = m.product_id
GROUP BY product_name
ORDER BY COUNT(product_name) DESC
;


-- 5) Which item was the most popular for each customer?

WITH cte_customer_order AS (   -- Using a CTE for this one
    SELECT 
        s.customer_id,
        m.product_name, 
        COUNT(product_name) AS times_ordered,
        RANK() OVER (PARTITION BY s.customer_id ORDER BY COUNT(product_name) DESC) AS order_rank
    FROM
        sales s
    INNER JOIN
        menu m ON s.product_id = m.product_id
    GROUP BY 
        s.customer_id, m.product_name
)

SELECT 
    customer_id, product_name, times_ordered
FROM
    cte_customer_order
WHERE
    order_rank = 1;




-- 6) Which item was purchased first by the customer after they became a member?

WITH cte_customer_order AS (
SELECT 
	mbr.customer_id,
	mbr.join_date,
	s.order_date,
	s.product_id,
	m.product_name,
	RANK() OVER (PARTITION BY s.customer_id ORDER BY order_date) AS order_rank
from members mbr
right join sales s on mbr.customer_id = s.customer_id -- Right join to exclude customers that are not a member
left join menu m on s.product_id = m.product_id
where mbr.customer_id is not null AND s.order_date > mbr.join_date
order by customer_id, s.order_date ASC
)

select customer_id, product_name
FROM cte_customer_order
where order_rank = 1
;



-- 7) Which item was purchased just before the customer became a member?

WITH cte_customer_order AS (
SELECT 
	mbr.customer_id,
	mbr.join_date,
	s.order_date,
	s.product_id,
	m.product_name,
	RANK() OVER (PARTITION BY s.customer_id ORDER BY order_date desc) AS order_rank
from members mbr
right join sales s on mbr.customer_id = s.customer_id -- Right join to exclude customers that are not a member
left join menu m on s.product_id = m.product_id
where mbr.customer_id is not null AND s.order_date < mbr.join_date
order by customer_id, s.order_date desc
)

select customer_id, product_name
FROM cte_customer_order
where order_rank = 1
;




-- 8) What is the total items and amount spent for each member before they became a member?


    SELECT 
        mbr.customer_id,
        count(s.product_id) as count_of_products,
        sum(m.price) as total_spent
    FROM 
        members mbr
    INNER JOIN 
        sales s ON mbr.customer_id = s.customer_id -- Inner join to exclude customers that are not a member
    LEFT JOIN 
        menu m ON s.product_id = m.product_id
    WHERE
        s.order_date < mbr.join_date
    GROUP BY
		mbr.customer_id
    ORDER BY 
        customer_id
	;


-- 9) If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?


    SELECT 
        mbr.customer_id,
        SUM(
            CASE
                WHEN m.product_name = 'sushi' THEN (price * 10) * 2 -- double points for sushi
                ELSE m.price * 10 -- regular points for all other products
            END
        ) AS points_earned
    FROM 
        members mbr
    INNER JOIN 
        sales s ON mbr.customer_id = s.customer_id
    LEFT JOIN 
        menu m ON s.product_id = m.product_id
    WHERE 
       s.order_date >= mbr.join_date -- We only count purchases on or after join date
    GROUP BY 
        customer_id
    ORDER BY 
        customer_id;



-- 10) In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

    SELECT 
        mbr.customer_id,
        SUM(
            CASE
				WHEN DATEDIFF(s.order_date, mbr.join_date) <= 7 THEN  m.price * 20 -- Orders in the first 7 days get double points
                WHEN m.product_name = 'sushi' THEN (price * 10) * 2 -- double points for sushi
                ELSE m.price * 10 -- regular points for every other case
            END
        ) AS points_earned
    FROM 
        members mbr
    INNER JOIN 
        sales s ON mbr.customer_id = s.customer_id
    LEFT JOIN 
        menu m ON s.product_id = m.product_id
    WHERE 
       s.order_date >= mbr.join_date -- We only count purchases on or after join date
       AND s.order_date < '2021-02-01'-- Promo ends in January
    GROUP BY 
        customer_id
    ORDER BY 
        customer_id;


/* 11) Bonus question
The following questions are related creating basic data tables that Danny 
and his team can use to quickly derive insights without needing to join the underlying tables using SQL.

Recreate the following table output using the available data:
*/

select s.customer_id, s.order_date, m.product_name, m.price,
CASE
WHEN order_date >= join_date THEN 'Y'
ELSE 'N'
END AS is_member
from sales s
LEFT JOIN menu m on s.product_id = m.product_id
left join members mbr on s.customer_id = mbr.customer_id
order by s.customer_id, s.order_date
;

/*
12) Danny also requires further information about the ranking of customer products, 
but he purposely does not need the ranking for non-member purchases so he expects null ranking values
for the records when customers are not yet part of the loyalty program.
*/

WITH cte_all_orders AS (
    SELECT 
        s.customer_id, 
        s.order_date, 
        m.product_name, 
        m.price,
        CASE
            WHEN s.order_date >= mbr.join_date THEN 'Y'
            ELSE 'N'
        END AS is_member
    FROM sales s
    LEFT JOIN menu m ON s.product_id = m.product_id
    LEFT JOIN members mbr ON s.customer_id = mbr.customer_id
)
SELECT 
    * ,
    CASE
        WHEN is_member = 'Y' THEN RANK() OVER (PARTITION BY customer_id, is_member ORDER BY order_date)
        ELSE NULL
    END AS ranking
FROM cte_all_orders;

