USE clique_bait;

/* Digital Analysis */
/* 1. How many users are there? */

SELECT 
    COUNT(DISTINCT user_id) as Total_Users
FROM
    users;


/* 2. How many cookies does each user have on average? */

WITH cte AS
(
 SELECT user_id, COUNT(cookie_id) as cnt
 FROM users
 GROUP BY user_id
 )
SELECT ROUND(avg(cnt),2 ) as AVG_Cookie_Per_User FROM cte;


/* 3. What is the unique number of visits by all users per month? */

SELECT 
    MONTH(e.event_time) AS Month_Num,
    MONTHNAME(e.event_time) AS Month_Name,
    COUNT(DISTINCT visit_id) AS tot_number_of_visits
FROM
    users u
        LEFT JOIN
    events e ON u.cookie_id = e.cookie_id
GROUP BY 1 , 2
ORDER BY 1;


/* 4. What is the number of events for each event type? */

SELECT 
    e.event_type, ei.event_name, COUNT(e.visit_id) as counts
FROM
    events e
        INNER JOIN
    event_identifier ei ON e.event_type = ei.event_type
GROUP BY e.event_type , ei.event_name;


/* 5. What is the percentage of visits which have a purchase event? */

SELECT 
    ROUND(((SELECT 
                    COUNT(DISTINCT visit_id)
                FROM
                    events
                WHERE
                    event_type = 3) / (SELECT 
                    COUNT(DISTINCT visit_id)
                FROM
                    events
                WHERE
                    event_type = 1)) * 100,
            2) AS Purchase_percentage;


/* 6. What is the percentage of visits which view the checkout page but do not have a purchase event? */
 
WITH cte AS
(
SELECT 
CASE WHEN page_id = 12 THEN visit_id END as check_out,
Case WHEN event_type = 3 THEN visit_id END as pur
FROM events
)
SELECT COUNT(check_out) AS Total_viewed_checkout, 
	COUNT(pur) AS Total_purchased ,
    ROUND((COUNT(check_out) - COUNT(pur))/(COUNT(check_out))*100,2) as percentage 
    FROM cte;


/* 7. What are the top 3 pages by number of views? */

SELECT 
    p.page_name, COUNT(e.page_id) AS Num_of_visits
FROM
    events e
        INNER JOIN
    page_hierarchy p ON e.page_id = p.page_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 3;


/* 8. What is the number of views and cart adds for each product category? */

SELECT 
    p.product_category,
    COUNT(CASE
        WHEN e.event_type = 1 THEN e.visit_id
    END) AS pg_view,
    COUNT(CASE
        WHEN e.event_type = 2 THEN e.visit_id
    END) AS cart
FROM
    events e
        LEFT JOIN
    page_hierarchy p ON e.page_id = p.page_id
        LEFT JOIN
    event_identifier i ON e.event_type = i.event_type
WHERE
    p.product_category IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC;


/* 9. What are the top 3 products by purchases? */

WITH cte AS (
  SELECT DISTINCT visit_id AS purchase_id
  FROM events 
  WHERE event_type = 3
),
cte2 AS (
  SELECT 
    p.page_name,
    p.page_id,
    e.visit_id 
  FROM events e
  LEFT JOIN page_hierarchy p ON p.page_id = e.page_id
  WHERE p.product_id IS NOT NULL 
    AND e.event_type = 2
)
SELECT 
  page_name as Product,
  COUNT(*) AS Quantity_Purchased
FROM cte 
LEFT JOIN cte2 ON visit_id = purchase_id 
GROUP BY 1
ORDER BY 2 DESC
LIMIT 3
;


/* Product Funnel Analysis */
/* 1. Using a single SQL query - create a new output table which has the following details:

How many times was each product viewed?
How many times was each product added to cart?
How many times was each product added to a cart but not purchased (abandoned)?
How many times was each product purchased? */

CREATE TABLE product_info as
WITH cte as (
SELECT 
    e.visit_id,
    e.cookie_id,
    e.page_id,
    e.event_type,
    p.page_name,
    p.product_category,
    p.product_id
FROM
    events e
        INNER JOIN
    page_hierarchy p ON e.page_id = p.page_id
),
cte2 as
(
SELECT 
    page_name,
    CASE
        WHEN event_type = 1 THEN visit_id
    END AS pg_view,
    CASE
        WHEN event_type = 2 THEN visit_id
    END AS cart
FROM
    cte
WHERE
    product_id IS NOT NULL
),
cte3 as 
(
SELECT 
    visit_id AS purr
FROM
    events
WHERE
    event_type = 3
)
SELECT 
    page_name,
    COUNT(pg_view) AS Page_Views,
    COUNT(cart) AS Added_to_cart,
    (COUNT(cart) - COUNT(purr)) AS Abandoned,
    COUNT(purr) AS Purchase
FROM
    cte2
        LEFT JOIN
    cte3 ON cart = purr
GROUP BY page_name
ORDER BY 5 DESC;


/* 2. Create another table which further aggregates the data for the above points(refer to previous question) but this time for each product category instead of individual products. */

Create Table product_category_info as
WITH cte as
(
SELECT 
    e.visit_id,
    e.event_type,
    e.page_id,
    p.page_name,
    p.product_id,
    p.product_category
FROM
    events e
        INNER JOIN
    page_hierarchy p ON e.page_id = p.page_id
),
cte2 as 
(
SELECT 
    product_category,
    CASE
        WHEN event_type = 1 THEN visit_id
    END AS pg_view,
    CASE
        WHEN event_type = 2 THEN visit_id
    END AS cart
FROM
    cte
WHERE
    product_category IS NOT NULL
),
cte3 as
(
SELECT 
    visit_id AS purr
FROM
    events
WHERE
    event_type = 3
)
SELECT 
    product_category AS Product_Category,
    COUNT(pg_view) AS Page_Views,
    COUNT(cart) AS Added_to_cart,
    (COUNT(cart) - COUNT(purr)) AS Abandoned,
    COUNT(purr) AS Purchase
FROM
    cte2
        LEFT JOIN
    cte3 ON cart = purr
GROUP BY 1;


/* 3. Which product had the most views, cart adds and purchases? */

SELECT 
    page_name AS Most_Viewed
FROM
    product_info
WHERE
    Page_Views = (SELECT 
            MAX(Page_Views)
        FROM
            product_info);

SELECT 
    page_name AS Most_Cart_adds
FROM
    product_info
WHERE
    Added_to_cart = (SELECT 
            MAX(Added_to_cart)
        FROM
            product_info);

SELECT 
    page_name AS Most_Purchased
FROM
    product_info
WHERE
    Purchase = (SELECT 
            MAX(Purchase)
        FROM
            product_info);


/* 4. Which product was most likely to be abandoned? */

SELECT 
    page_name AS Most_likely_abondoned
FROM
    product_info
WHERE
    Abandoned = (SELECT 
            MAX(Abandoned)
        FROM
            product_info);

/* 5. Which product had the highest view to purchase percentage? */

SELECT 
    page_name,
    ROUND((Purchase / Page_Views) * 100, 2) AS View_Purchase_percent
FROM
    product_info
ORDER BY 2 DESC
LIMIT 1;


/* 6. What is the average conversion rate from view to cart add? */

WITH cte as 
( SELECT * , ROUND( (Added_to_cart/Page_Views)*100 , 2) as conversion_rate
FROM product_info )

SELECT ROUND(AVG(conversion_rate),2) as Conversion_rate from cte;


/* 7. What is the average conversion rate from cart add to purchase? */

WITH cte as 
( SELECT * , ROUND( (Purchase/Added_to_cart)*100 , 2) as conversion_rate
FROM product_info )

SELECT ROUND(avg(conversion_rate),2) as Conversion_rate FROM cte;

/* Campaign Analysis */
/* Generate a table that has 1 single row for every unique visit_id record and has the following columns:
1. user_id
2. visit_id
3. visit_start_time: the earliest event_time for each visit
4. page_views: count of page views for each visit
5. cart_adds: count of product cart add events for each visit
6. purchase: 1/0 flag if a purchase event exists for each visit
7. campaign_name: map the visit to a campaign if the visit_start_time falls between the start_date and end_date
8. impression: count of ad impressions for each visit
9. click: count of ad clicks for each visit */

WITH cte as
(
SELECT 
    user_id,
    visit_id,
    MIN(e.event_time) AS visit_start_time,
    COUNT(CASE
        WHEN event_type = 1 THEN visit_id
    END) AS Page_views,
    COUNT(CASE
        WHEN event_type = 2 THEN visit_id
    END) AS Cart_adds,
    COUNT(CASE
        WHEN event_type = 3 THEN visit_id
    END) AS Purchase,
    COUNT(CASE
        WHEN e.event_type = 4 THEN e.visit_id
    END) AS Impression,
    COUNT(CASE
        WHEN e.event_type = 5 THEN e.visit_id
    END) AS Click
FROM
    users u
        INNER JOIN
    events e ON u.cookie_id = e.cookie_id	
GROUP BY 1,2
)

SELECT 
    user_id,
    visit_id,
    visit_start_time,
    Page_views,
    Cart_adds,
    Purchase,
    Impression,
    Click,
    CASE
        WHEN visit_start_time BETWEEN ci.start_date AND ci.end_date THEN ci.campaign_name
    END AS Campaign_name
FROM
    cte
        JOIN
    campaign_identifier ci ON visit_start_time BETWEEN ci.start_date AND ci.end_date
        JOIN
    page_hierarchy p ON page_id = p.page_id
ORDER BY 1 , 2;
        
       























