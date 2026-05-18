-- ============================================================
-- STEP 0: UNIFY THE PARTITIONED TABLES (The Silver View)
-- ============================================================
CREATE VIEW vw_unified_mandi AS
SELECT * FROM clean_mandi_2023
UNION ALL
SELECT * FROM clean_mandi_2024
UNION ALL
SELECT * FROM clean_mandi_2025
UNION ALL
SELECT * FROM clean_mandi_2026;

-- ============================================================
-- STEP 1: CREATE DIMENSION TABLES (The "Text" Data)
-- ============================================================

-- 1. Location Dimension
CREATE TABLE dim_location AS
SELECT DISTINCT 
    MD5(CONCAT(`STATE`, `District Name`, `Market Name`)) AS location_id,
    `STATE` AS state,
    `District Name` AS district,
    `Market Name` AS market
FROM vw_unified_mandi;

-- 2. Commodity Dimension
CREATE TABLE dim_commodity AS
SELECT DISTINCT 
    MD5(CONCAT(`Commodity`, `Variety`, `Grade`)) AS commodity_id,
    `Commodity` AS commodity_name,
    `Variety` AS variety,
    `Grade` AS grade
FROM vw_unified_mandi;

-- 3. Date Dimension (The Bulletproof Date Parser)
CREATE TABLE dim_date AS
SELECT DISTINCT 
    `Price Date` AS date_id,
    
    CASE 
        WHEN `Price Date` LIKE '%/%/%' THEN STR_TO_DATE(`Price Date`, '%m/%d/%Y')
        WHEN `Price Date` LIKE '%-%-%' THEN STR_TO_DATE(`Price Date`, '%d-%m-%Y')
        ELSE NULL 
    END AS full_date,
    
    YEAR(
        CASE 
            WHEN `Price Date` LIKE '%/%/%' THEN STR_TO_DATE(`Price Date`, '%m/%d/%Y')
            WHEN `Price Date` LIKE '%-%-%' THEN STR_TO_DATE(`Price Date`, '%d-%m-%Y')
            ELSE NULL 
        END
    ) AS sales_year,
    
    MONTH(
        CASE 
            WHEN `Price Date` LIKE '%/%/%' THEN STR_TO_DATE(`Price Date`, '%m/%d/%Y')
            WHEN `Price Date` LIKE '%-%-%' THEN STR_TO_DATE(`Price Date`, '%d-%m-%Y')
            ELSE NULL 
        END
    ) AS sales_month
    
FROM vw_unified_mandi;

-- ============================================================
-- STEP 2: CREATE THE FACT TABLE (The "Numbers" Data)
-- ============================================================

CREATE TABLE fact_mandi_prices AS
SELECT 
    MD5(CONCAT(`STATE`, `District Name`, `Market Name`)) AS location_id,
    MD5(CONCAT(`Commodity`, `Variety`, `Grade`)) AS commodity_id,
    `Price Date` AS date_id,
    `Min_Price`,
    `Max_Price`,
    `Modal_Price`,
    (`Max_Price` - `Min_Price`) AS Price_Spread
FROM vw_unified_mandi;