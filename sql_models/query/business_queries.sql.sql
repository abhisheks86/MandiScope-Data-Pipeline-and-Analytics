USE mandi;
-- =========================================================================
-- QUERY 1: THE ARBITRAGE FINDER
-- Business Goal: Identify the largest price differences for the exact same 
-- commodity, on the same day, within the same state.
-- =========================================================================

WITH DailyStatePrices AS (
    SELECT 
        d.full_date,
        l.state,
        c.commodity_name,
        c.variety,
        MAX(f.Modal_Price) AS Highest_State_Price,
        MIN(f.Modal_Price) AS Lowest_State_Price,
        (MAX(f.Modal_Price) - MIN(f.Modal_Price)) AS Arbitrage_Spread_INR
    FROM fact_mandi_prices f
    JOIN dim_location l ON f.location_id = l.location_id
    JOIN dim_commodity c ON f.commodity_id = c.commodity_id
    JOIN dim_date d ON f.date_id = d.date_id
    WHERE f.Modal_Price > 0 -- Clean out any zero-price errors
      AND d.full_date IS NOT NULL
    GROUP BY 
        d.full_date,
        l.state,
        c.commodity_name,
        c.variety
    HAVING Arbitrage_Spread_INR > 500 -- Only show major price gaps over 500 INR
)
SELECT 
    full_date,
    state,
    commodity_name,
    variety,
    Highest_State_Price,
    Lowest_State_Price,
    Arbitrage_Spread_INR
FROM DailyStatePrices
ORDER BY Arbitrage_Spread_INR DESC
LIMIT 100;

-- =========================================================================
-- QUERY 2: THE INFLATION TRACKER (Month-over-Month Trend)
-- Business Goal: Track the average monthly price of essential commodities 
-- and use Window Functions to calculate Month-over-Month (MoM) inflation.
-- =========================================================================

WITH MonthlyAverages AS (
    SELECT 
        d.sales_year,
        d.sales_month,
        c.commodity_name,
        AVG(f.Modal_Price) AS avg_monthly_price
    FROM fact_mandi_prices f
    JOIN dim_date d ON f.date_id = d.date_id
    JOIN dim_commodity c ON f.commodity_id = c.commodity_id
    WHERE c.commodity_name IN ('Tomato', 'Onion', 'Potato') -- The "TOP" essential crops
      AND d.sales_year IS NOT NULL
    GROUP BY 
        d.sales_year,
        d.sales_month,
        c.commodity_name
),
MoM_Calculation AS (
    SELECT 
        sales_year,
        sales_month,
        commodity_name,
        ROUND(avg_monthly_price, 2) AS current_price,
        -- The LAG function looks at the previous month's price for the exact same commodity
        LAG(ROUND(avg_monthly_price, 2)) OVER (
            PARTITION BY commodity_name 
            ORDER BY sales_year, sales_month
        ) AS previous_month_price
    FROM MonthlyAverages
)
SELECT 
    sales_year,
    sales_month,
    commodity_name,
    current_price,
    previous_month_price,
    -- Calculate the exact inflation/deflation percentage
    ROUND(((current_price - previous_month_price) / previous_month_price) * 100, 2) AS mom_inflation_percent
FROM MoM_Calculation
WHERE previous_month_price IS NOT NULL
ORDER BY commodity_name, sales_year, sales_month;

-- =========================================================================
-- QUERY 3: THE VOLATILITY & RISK INDEX
-- Business Goal: Identify the most volatile commodities by calculating the 
-- average daily price spread as a percentage of the modal (average) price.
-- High volatility = High risk for buyers and sellers.
-- =========================================================================

SELECT 
    c.commodity_name,
    d.sales_year,
    COUNT(f.date_id) AS Total_Trading_Days,
    ROUND(AVG(f.Price_Spread), 2) AS Average_Daily_Spread_INR,
    ROUND(AVG(f.Modal_Price), 2) AS Average_Modal_Price_INR,
    -- Calculate the risk percentage (Spread / Price * 100)
    ROUND((AVG(f.Price_Spread) / AVG(f.Modal_Price)) * 100, 2) AS Volatility_Percentage
FROM fact_mandi_prices f
JOIN dim_commodity c ON f.commodity_id = c.commodity_id
JOIN dim_date d ON f.date_id = d.date_id
WHERE f.Modal_Price > 0 -- Prevent division by zero errors
  AND d.sales_year IS NOT NULL
GROUP BY 
    c.commodity_name,
    d.sales_year
HAVING Total_Trading_Days > 50 -- Filter out rare crops; only show items with 50+ days of data
ORDER BY Volatility_Percentage DESC
LIMIT 100;

-- =========================================================================
-- QUERY 4: THE SEASONALITY ANALYZER (Historical Harvest Cycles)
-- Business Goal: Determine the historical cheapest and most expensive months 
-- to procure key commodities by aggregating all years of data.
-- =========================================================================

WITH MonthlyAggregates AS (
    SELECT 
        c.commodity_name,
        d.sales_month,
        ROUND(AVG(f.Modal_Price), 2) AS historical_avg_price
    FROM fact_mandi_prices f
    JOIN dim_commodity c ON f.commodity_id = c.commodity_id
    JOIN dim_date d ON f.date_id = d.date_id
    WHERE c.commodity_name IN ('Potato', 'Tomato', 'Onion')
      AND d.sales_month IS NOT NULL
    GROUP BY 
        c.commodity_name,
        d.sales_month
),
RankedSeasonality AS (
    SELECT 
        commodity_name,
        sales_month,
        historical_avg_price,
        -- The RANK function orders the months from cheapest (1) to most expensive (12)
        RANK() OVER(PARTITION BY commodity_name ORDER BY historical_avg_price ASC) as price_rank
    FROM MonthlyAggregates
)
SELECT 
    commodity_name,
    sales_month,
    historical_avg_price,
    CASE 
        WHEN price_rank = 1 THEN 'Cheapest Month (Max Buy)'
        WHEN price_rank = 12 THEN 'Most Expensive Month (Sell/Avoid)'
        WHEN price_rank <= 3 THEN 'Favorable Buying Window'
        ELSE 'Standard'
    END AS procurement_action
FROM RankedSeasonality
ORDER BY commodity_name, sales_month;