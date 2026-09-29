SELECT TOP (1000) [transaction_id]
      ,[applicant_id]
      ,[transaction_date]
      ,[transaction_type]
      ,[amount_ngn]
      ,[provider]
      ,[counterparty_type]
  FROM [unbanked lending trust].[dbo].[mobile_money_transactions]


   --Data Cleaning

  --Inspect the transaction_type, provider and counterparty_type
  SELECT
  DISTINCT transaction_type, provider , counterparty_type
FROM
  [unbanked lending trust].[dbo].[mobile_money_transactions]

--Inspect the amount Column
SELECT
  MIN(amount_ngn) AS min_amount_ngn,
  MAX(amount_ngn) AS max_amount_ngn
FROM
 [unbanked lending trust].[dbo].[mobile_money_transactions]


 --- Checking the data type
 SELECT
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'mobile_money_transactions'
  AND COLUMN_NAME = 'amount_ngn';


  --Find values that can't be converted
  SELECT
    amount_ngn
FROM
    [unbanked lending trust].[dbo].[mobile_money_transactions]
WHERE
    TRY_CAST(amount_ngn AS DECIMAL(18,2)) IS NULL
    AND amount_ngn IS NOT NULL;


    --Change the empty to NULL
    UPDATE [unbanked lending trust].[dbo].[mobile_money_transactions]
SET amount_ngn = NULL
WHERE TRIM(amount_ngn) = '';

--CHECK IF IT HAS BEEN CHANGED
    SELECT
    amount_ngn
FROM
    [unbanked lending trust].[dbo].[mobile_money_transactions]
WHERE
    TRIM(amount_ngn) = '';

 --Amount_ngn is in text so we  need to convert it
  ALTER TABLE [unbanked lending trust].[dbo].[mobile_money_transactions]
ALTER COLUMN amount_ngn DECIMAL(18,2);


--Inspect the amount Column
SELECT
  MIN(amount_ngn) AS min_amount_ngn,
  MAX(amount_ngn) AS max_amount_ngn
FROM
 [unbanked lending trust].[dbo].[mobile_money_transactions]


--Analyzing Data
SELECT
  *
FROM
  [unbanked lending trust].[dbo].[mobile_money_transactions]
ORDER BY
  amount_ngn DESC 

--Analyzing Data cont'd
SELECT
  *
FROM
[unbanked lending trust].[dbo].[mobile_money_transactions]
   WHERE
  transaction_type = 'Receive'
ORDER BY
  amount_ngn DESC
