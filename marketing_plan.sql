
-- =====================================================================
-- CREATING A MARKETING PLAN TABLE
-- =====================================================================
CREATE TABLE marketing_action_plan AS
SELECT 
    segment,
    customer_count,
    total_revenue,
    CASE segment
        WHEN '1-Champions' THEN 
            '🏆 VIP Treatment: Exclusive previews, loyalty rewards, premium service'
        WHEN '2-Loyal' THEN 
            '💎 Upsell: Recommend new releases, bundle offers, upgrade to premium'
        WHEN '3-At Risk' THEN 
            '🚨 WIN-BACK URGENTLY: Personalized "We miss you" email + special discount'
        WHEN '4-Sleepers' THEN 
            '📧 Re-engage: Newsletter with curated recommendations, limited-time offer'
        WHEN '5-Lost' THEN 
            '💤 Ignore or Low-Cost Reactivation: Not worth much effort unless very cheap'
        ELSE 'Monitor'
    END AS recommended_action,
    CASE segment
        WHEN '1-Champions' THEN 'High'
        WHEN '3-At Risk' THEN 'High'
        WHEN '2-Loyal' THEN 'Medium'
        WHEN '4-Sleepers' THEN 'Medium'
        ELSE 'Low'
    END AS marketing_budget_priority,
    CASE segment
        WHEN '1-Champions' THEN total_revenue * 0.15  -- Spend 15% of their value on retention
        WHEN '3-At Risk' THEN total_revenue * 0.20     -- Spend 20% to win them back
        WHEN '2-Loyal' THEN total_revenue * 0.10       -- Spend 10% on nurturing
        WHEN '4-Sleepers' THEN total_revenue * 0.05    -- Spend 5% on reactivation
        ELSE total_revenue * 0.01                      -- Minimal spend on lost
    END AS suggested_marketing_budget
FROM rfm_segment_summary;

-- Show the plan
SELECT 
    segment,
    customer_count AS customers,
    '$' || ROUND(total_revenue, 0) AS revenue,
    recommended_action AS action,
    marketing_budget_priority AS priority,
    '$' || ROUND(suggested_marketing_budget, 0) AS budget
FROM marketing_action_plan
ORDER BY 
    CASE marketing_budget_priority
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END,
    segment;

-- =====================================================================
-- SAMPLE CUSTOMERS FROM EACH SEGMENT
-- =====================================================================

WITH ranked_customers AS (
    SELECT 
        segment,
        first_name || ' ' || last_name AS customer_name,
        frequency AS rentals,
        monetary AS spent,
        recency_days AS days_ago,
        ROW_NUMBER() OVER (PARTITION BY segment ORDER BY monetary DESC) AS rn
    FROM rfm_segments
)
SELECT 
    segment,
    customer_name,
    rentals,
    '$' || spent AS spent,
    days_ago || ' days' AS last_rental
FROM ranked_customers
WHERE rn <= 3  -- Top 3 from each segment
ORDER BY segment, spent DESC;