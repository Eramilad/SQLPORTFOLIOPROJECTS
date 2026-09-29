SELECT TOP (1000) [record_id]
      ,[applicant_id]
      ,[transaction_date]
      ,[record_type]
      ,[item_category]
      ,[amount_ngn]
      ,[market_name]
  FROM [unbanked lending trust].[dbo].[market_trading_records]

  
  --Data Cleaning

  --Inspect the record_type and item_category
  SELECT
  DISTINCT record_type,item_category
FROM
  [unbanked lending trust].[dbo].[market_trading_records]

--Inspect the amount Column
SELECT
  MIN(amount_ngn) AS min_amount_ngn,
  MAX(amount_ngn) AS max_amount_ngn
FROM
 [unbanked lending trust].[dbo].[market_trading_records]


 --- Checking the data type
 SELECT
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'market_trading_records'
  AND COLUMN_NAME = 'amount_ngn';

 --Amount_ngn is in text so we  need to convert it
  ALTER TABLE [unbanked lending trust].[dbo].[market_trading_records]
ALTER COLUMN amount_ngn DECIMAL(18,2);


--Inspect the amount Column
SELECT
  MIN(amount_ngn) AS min_amount_ngn,
  MAX(amount_ngn) AS max_amount_ngn
FROM
 [unbanked lending trust].[dbo].[market_trading_records]


--Analyzing Data
SELECT
  *
FROM
  [unbanked lending trust].[dbo].[market_trading_records]
ORDER BY
  amount_ngn DESC 

--Analyzing Data cont'd
SELECT
  *
FROM
   [unbanked lending trust].[dbo].[market_trading_records]
   WHERE
  record_type IN ('Sale' , 'Expense')
ORDER BY
  amount_ngn DESC

  