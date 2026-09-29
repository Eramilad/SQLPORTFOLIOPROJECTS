SELECT TOP (1000) [payment_id]
      ,[applicant_id]
      ,[bill_type]
      ,[provider]
      ,[billing_month]
      ,[due_date]
      ,[payment_date]
      ,[amount_due_ngn]
      ,[amount_paid_ngn]
      ,[payment_status]
  FROM [unbanked lending trust].[dbo].[utility_bill_payments]


     --Data Cleaning

  --Inspect the payment_status, bill_type and provider
  SELECT
  DISTINCT payment_status, bill_type , provider
FROM
  [unbanked lending trust].[dbo].[utility_bill_payments]

--Inspect the amount_paid Column
SELECT
  MIN(amount_paid_ngn) AS min_amount_paid_ngn,
  MAX(amount_paid_ngn) AS max_amount_paid_ngn
FROM
 [unbanked lending trust].[dbo].[utility_bill_payments]


--Analyzing Data
SELECT
  *
FROM
  [unbanked lending trust].[dbo].[utility_bill_payments]
ORDER BY
  amount_paid_ngn DESC 

--Analyzing Data cont'd
SELECT
  *
FROM
  [unbanked lending trust].[dbo].[utility_bill_payments]
   WHERE
  payment_status = 'On-time'
ORDER BY
amount_paid_ngn DESC
