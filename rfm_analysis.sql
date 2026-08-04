SELECT * FROM rfm_analysis.retail_2009_2010;

CREATE TABLE retail_2009_2010 (
    Invoice VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate VARCHAR(30),
    Price DECIMAL(10,2),
    Customer_ID INT,
    Country VARCHAR(50)
);

select * from retail_2009_2010;

LOAD DATA INFILE 'J:\DATA ANALYST PROJECTS\PROJECT-2(RFM)\retail_2009_2010.csv'
INTO TABLE retail_2009_2010
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

SHOW VARIABLES LIKE 'secure_file_priv';

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/retail_2009_2010.csv'
INTO TABLE retail_2009_2010
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

TRUNCATE TABLE retail_2009_2010;

TRUNCATE TABLE retail_2009_2010;

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/retail_2009_2010.csv'
INTO TABLE retail_2009_2010
CHARACTER SET latin1
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(Invoice, StockCode, Description, Quantity, InvoiceDate, Price, @CustomerID, Country)
SET `Customer_ID` = NULLIF(@CustomerID, '');

SELECT * FROM retail_2009_2010 LIMIT 62299, 3;

CREATE TABLE retail_2010_2011 (
    Invoice VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate VARCHAR(30),
    Price DECIMAL(10,2),
    `Customer_ID` INT,
    Country VARCHAR(50)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/retail_2010_2011.csv'
INTO TABLE retail_2010_2011
CHARACTER SET latin1
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(Invoice, StockCode, Description, Quantity, InvoiceDate, Price, @CustomerID, Country)
SET `Customer_ID` = NULLIF(@CustomerID, '');

CREATE TABLE retail_combined AS
SELECT * FROM retail_2009_2010
UNION ALL
SELECT * FROM retail_2010_2011;

-- --------------------------------------------------------------------------------------------------------------------------- --

-- DATA CLEANING --

SELECT DISTINCT StockCode FROM retail_combined
WHERE StockCode NOT REGEXP '^[0-9]+[A-Za-z]*$';

SELECT DISTINCT StockCode, Description 
FROM retail_combined 
WHERE StockCode IN ('POST','D','DOT','M','C2','C3','BANK CHARGES','AMAZONFEE','CRUK','ADJUST','ADJUST2','S','B','TEST001','TEST002','GIFT','PADS','SP1002')
LIMIT 30;

CREATE TABLE retail_clean AS
SELECT * FROM retail_combined
WHERE StockCode NOT IN ('POST','D','DOT','M','C2','C3','BANK CHARGES','AMAZONFEE','CRUK','ADJUST','ADJUST2','S','B','TEST001','TEST002')
AND `Customer_ID` IS NOT NULL;

SELECT COUNT(*) FROM retail_clean WHERE Quantity < 0;
SELECT * FROM retail_clean WHERE Price < 0 ;

CREATE TABLE retail_final AS
SELECT * FROM retail_clean
WHERE Quantity > 0;

SELECT COUNT(*) FROM retail_final;

-- --------------------------------------------------------------------------------------------------------------------------- --
-- BIG THREE --

-- 1. RECENCY - for each customer, how many days since their last purchase? --
SELECT 
    Customer_ID,
    MAX(STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i')) AS last_purchase_date,
    DATEDIFF('2011-12-09', MAX(STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i'))) AS recency_days
FROM retail_final
GROUP BY Customer_ID
ORDER BY recency_days ASC;


-- 2. FREQUENCY - how many separate orders a customer has placed (more = better) --
SELECT Customer_ID, COUNT(DISTINCT( Invoice)) AS frequency
FROM retail_final
GROUP BY Customer_ID
ORDER BY frequency DESC;

-- 3. MONETARY — how much total revenue a customer has generated (more = better) --
select Customer_ID , sum(price*quantity) as total_revenue
from retail_final
group by Customer_ID
order by total_revenue desc;

-- CTE

WITH recency_cte AS (
    SELECT Customer_ID,
           DATEDIFF('2011-12-09', MAX(STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i'))) AS recency
    FROM retail_final
    GROUP BY Customer_ID
),
frequency_cte AS (
    SELECT Customer_ID, COUNT(DISTINCT Invoice) AS frequency
    FROM retail_final
    GROUP BY Customer_ID
),
monetary_cte AS (
    SELECT Customer_ID, SUM(Price * Quantity) AS monetary
    FROM retail_final
    GROUP BY Customer_ID
)
SELECT r.Customer_ID, r.recency, f.frequency, m.monetary
FROM recency_cte r
JOIN frequency_cte f ON r.Customer_ID = f.Customer_ID
JOIN monetary_cte m ON r.Customer_ID = m.Customer_ID;

-- --------------------------------------------------------- --

-- window function NITILE() statistical method--

WITH recency_cte AS (
    SELECT Customer_ID,
           DATEDIFF('2011-12-09', MAX(STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i'))) AS recency
    FROM retail_final
    GROUP BY Customer_ID
),
frequency_cte AS (
    SELECT Customer_ID, COUNT(DISTINCT Invoice) AS frequency
    FROM retail_final
    GROUP BY Customer_ID
),
monetary_cte AS (
    SELECT Customer_ID, SUM(Price * Quantity) AS monetary
    FROM retail_final
    GROUP BY Customer_ID
),
rfm_base AS (
    SELECT r.Customer_ID, r.recency, f.frequency, m.monetary
    FROM recency_cte r
    JOIN frequency_cte f ON r.Customer_ID = f.Customer_ID
    JOIN monetary_cte m ON r.Customer_ID = m.Customer_ID
)
SELECT Customer_ID, recency, frequency, monetary,
    NTILE(4) OVER (ORDER BY recency ASC) AS r_score,
    NTILE(4) OVER (ORDER BY frequency DESC) AS f_score,
    NTILE(4) OVER (ORDER BY monetary DESC) AS m_score
FROM rfm_base;


-- segmentation

WITH recency_cte AS (
    SELECT Customer_ID,
    DATEDIFF('2011-12-09', MAX(STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i'))) AS recency
    FROM retail_final
    GROUP BY Customer_ID
),
frequency_cte AS (
    SELECT Customer_ID, COUNT(DISTINCT Invoice) AS frequency
    FROM retail_final
    GROUP BY Customer_ID
),
monetary_cte AS (
    SELECT Customer_ID, SUM(Price * Quantity) AS monetary
    FROM retail_final
    GROUP BY Customer_ID
),
rfm_base AS (
    SELECT r.Customer_ID, r.recency, f.frequency, m.monetary
    FROM recency_cte r
    JOIN frequency_cte f ON r.Customer_ID = f.Customer_ID
    JOIN monetary_cte m ON r.Customer_ID = m.Customer_ID
),
rfm_scores AS (
    SELECT Customer_ID, recency, frequency, monetary,
        NTILE(4) OVER (ORDER BY recency ASC) AS r_score,
        NTILE(4) OVER (ORDER BY frequency DESC) AS f_score,
        NTILE(4) OVER (ORDER BY monetary DESC) AS m_score
    FROM rfm_base
),
rfm_final AS (
    SELECT *,
        (r_score + f_score + m_score) AS rfm_total,
        CASE 
            WHEN (r_score + f_score + m_score) <= 4 THEN 'Champion'
            WHEN (r_score + f_score + m_score) <= 7 THEN 'Loyal'
            WHEN (r_score + f_score + m_score) <= 9 THEN 'At Risk'
            ELSE 'Lost'
        END AS segment
    FROM rfm_scores
)
SELECT segment, COUNT(*) AS customer_count
FROM rfm_final
GROUP BY segment
ORDER BY customer_count DESC;

-- business-rule approach --

WITH recency_cte AS(
	select Customer_ID, 
    datediff('2011-12-09',MAX(STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i'))) AS recency
    FROM retail_final
    group by Customer_ID
),
frequency_cte AS(
	select Customer_ID,
    count(distinct Invoice) AS frequency
    from retail_final
    group by Customer_ID
),
monetary_cte AS(
	select Customer_ID, sum(Price*Quantity) as monetary
    from retail_final
    group by Customer_ID
),
rfm_base AS (
    SELECT r.Customer_ID, r.recency, f.frequency, m.monetary
    FROM recency_cte r
    JOIN frequency_cte f ON r.Customer_ID = f.Customer_ID
    JOIN monetary_cte m ON r.Customer_ID = m.Customer_ID
),
 rfm_scores as (
 SELECT *,
    CASE 
        WHEN recency <= 30 AND frequency >= 10 AND monetary >= 2000 THEN 'Champion'
        WHEN recency <= 90 AND frequency >= 3 THEN 'Loyal'
        WHEN recency > 90 AND frequency >= 3 THEN 'At Risk'
        ELSE 'Lost'
    END AS segment_rules
	FROM rfm_base
)
select segment_rules,count(*) as segment_count
from rfm_scores
group by segment_rules
order by segment_count desc;

-- ========================================END======================================================== --