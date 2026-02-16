-- =====================================================================
-- RFM ANALYSIS - DVD RENTAL DATASET
-- =====================================================================
-- Drop TABLES IF EXISTS
DROP TABLE IF EXISTS rfm_scores CASCADE;
DROP TABLE IF EXISTS rfm_segments CASCADE;
DROP TABLE IF EXISTS rfm_segment_summary CASCADE;

-- =====================================================================
-- Calculate RFM Scores for Each Customer
-- =====================================================================

CREATE TABLE rfm_scores AS
WITH customer_rfm AS (
    -- Calculate R, F, M for each customer
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        -- RECENCY: Days since last rental 
        (SELECT MAX(rental_date)::DATE FROM rental) - MAX(r.rental_date)::DATE AS recency_days,
        -- FREQUENCY: Total number of rentals 
        COUNT(r.rental_id) AS frequency,
        -- MONETARY: Total amount spent
        COALESCE(SUM(p.amount), 0) AS monetary
    FROM customer c
    INNER JOIN rental r ON c.customer_id = r.customer_id
    LEFT JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY c.customer_id, c.customer_id, c.first_name, c.last_name, c.email
)
SELECT 
    customer_id,
    first_name,
    last_name,
    email,
    recency_days,
    frequency,
    monetary,
    -- Recency Score: 5 = most recent, 1 = least recent
    NTILE(5) OVER (ORDER BY recency_days DESC) AS recency_score,
    -- Frequency Score: 5 = most frequent, 1 = least frequent
    NTILE(5) OVER (ORDER BY frequency ASC) AS frequency_score,
    -- Monetary Score: 5 = highest spender, 1 = lowest spender
    NTILE(5) OVER (ORDER BY monetary ASC) AS monetary_score,
    -- Combined RFM Score
    CAST( NTILE(5) OVER (ORDER BY recency_days DESC) AS VARCHAR) || 
        CAST(NTILE(5) OVER (ORDER BY frequency ASC) AS VARCHAR) || 
        CAST(NTILE(5) OVER (ORDER BY monetary ASC) AS VARCHAR) AS rfm_score,
    -- Total Score
    NTILE(5) OVER (ORDER BY recency_days DESC) + 
    NTILE(5) OVER (ORDER BY frequency ASC) + 
    NTILE(5) OVER (ORDER BY monetary ASC) AS rfm_total
FROM customer_rfm;
-- =====================================================================
-- Create Customer Segments Based on RFM
-- =====================================================================

CREATE TABLE rfm_segments AS
SELECT 
    customer_id,
    first_name,
    last_name,
    email,
    recency_days,
    frequency,
    monetary,
    recency_score,
    frequency_score,
    monetary_score,
    rfm_score,
    rfm_total,
    
    -- SIMPLIFIED 5-SEGMENT MODEL
    CASE 
        -- 1. CHAMPIONS: High R, F, M (scores 4-5)
        -- Buy recently, buy often, spend a lot
        WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN '1-Champions'
        
        -- 2. LOYAL: Good on all fronts (scores 3-5)
        -- Regular customers, decent spending
        WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score >= 3 THEN '2-Loyal'
        
        -- 3. AT RISK: Were good but becoming inactive (High F/M, Low R)
        -- Used to be great customers but haven't returned lately
        WHEN recency_score <= 2 AND (frequency_score >= 3 OR monetary_score >= 3) THEN '3-At Risk'
        
        -- 4. SLEEPERS: Some activity but declining (Medium R/F/M)
        -- Inconsistent customers who might be salvageable
        WHEN recency_score >= 2 AND recency_score <= 3 THEN '4-Sleepers'
        
        -- 5. LOST: Low on everything (scores 1-2)
        -- Haven't bought recently, rarely buy, spend little
        ELSE '5-Lost'
    END AS segment,
    
    -- Priority Level for Action
    CASE 
        WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'P1-Retain'
        WHEN recency_score <= 2 AND (frequency_score >= 3 OR monetary_score >= 3) THEN 'P2-Win Back'
        WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'P3-Nurture'
        ELSE 'P4-Monitor'
    END AS priority,
    
    -- Simple Health Score (1-10)
    ROUND((recency_score + frequency_score + monetary_score) / 15.0 * 10, 1) AS health_score
    
FROM rfm_scores;

-- =====================================================================
-- Create Summary Statistics Table
-- =====================================================================

CREATE TABLE rfm_segment_summary AS
SELECT 
    segment,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*)::NUMERIC / (SELECT COUNT(*) FROM rfm_segments) * 100, 1) AS pct_customers,
    ROUND(AVG(recency_days), 0) AS avg_days_since_rental,
    ROUND(AVG(frequency), 1) AS avg_rentals,
    ROUND(AVG(monetary), 2) AS avg_spend,
    SUM(monetary) AS total_revenue,
    ROUND(SUM(monetary) / (SELECT SUM(monetary) FROM rfm_segments) * 100, 1) AS pct_revenue,
    ROUND(AVG(health_score), 1) AS avg_health_score,
    MIN(monetary) AS min_spend,
    MAX(monetary) AS max_spend
FROM rfm_segments
GROUP BY segment
ORDER BY segment;