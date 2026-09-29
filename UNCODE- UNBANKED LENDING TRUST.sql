SELECT TOP (1000) [topup_id]
      ,[applicant_id]
      ,[topup_date]
      ,[network_provider]
      ,[topup_type]
      ,[amount_ngn]
      ,[payment_method]
  FROM [unbanked lending trust].[dbo].[airtime_topup_history]



/*
   ============================================================
   Trusting the Unbanked — Alt-Data Credit Scoring
   ============================================================
   IMPORTANT LIMITATION: loan_status (Approved/Pending/Rejected) 
   in this dataset was synthetically generated with no built-in 
   relationship to the alt-data fields below (airtime, mobile 
   money, utility payments, market sales). There is also no 
   repayment-outcome table in this database.

   That means the validation section near the end of this script 
   checks whether the alt-data score aligns with EXISTING approval 
   decisions — not whether it predicts actual repayment. Results 
   showed no consistent trend, which is an honest and expected 
   outcome given the synthetic labels aren't causally tied to the 
   inputs. This script demonstrates the SQL pipeline and scoring 
   methodology, not a validated predictive model.
*/
  --Data Cleaning

  --Inspect the network provider and topup type column
  SELECT
  DISTINCT network_provider, topup_type
FROM
  [unbanked lending trust].[dbo].[airtime_topup_history]

--Inspect the amount Column
SELECT
  MIN(amount_ngn) AS min_amount_ngn,
  MAX(amount_ngn) AS max_amount_ngn
FROM
  [unbanked lending trust].[dbo].[airtime_topup_history]


--Analyzing Data
SELECT
  *
FROM
  [unbanked lending trust].[dbo].[airtime_topup_history]
ORDER BY
  amount_ngn DESC 

  --Amount_ngn is in text so we  need to conVert it
  ALTER TABLE [unbanked lending trust].[dbo].[airtime_topup_history]
ALTER COLUMN amount_ngn DECIMAL(18,2);


--Analyzing Data cont'd
SELECT
  *
FROM
  [unbanked lending trust].[dbo].[airtime_topup_history]
ORDER BY
  amount_ngn DESC 


  /*
   Extra features — digging deeper than just totals.

   The alt-data score I built earlier only uses total amounts per 
   category (total spent, total paid, etc). That's a decent start, 
   but it rewards "spent a lot once" the same as "consistently active 
   over time" — which isn't really fair. These queries pull out some 
   better signals: how consistent someone is, how on-time they are, 
   and how their activity compares to their income.

   Plan is to fold the useful ones into the score before finalizing it,
   rather than treating this as a separate side analysis.
*/

-- How many different months was this person actually active?
-- Someone active across 6 different months looks more reliable than 
-- someone who did all their spending in one week.
SELECT
    applicant_id,
    COUNT(DISTINCT FORMAT(topup_date, 'yyyy-MM')) AS active_months
FROM [unbanked lending trust].[dbo].[airtime_topup_history]
GROUP BY applicant_id;



/*
   topup_date was stored as text, not an actual date — that's why 
   FORMAT() kept failing on it earlier (same issue we had with the 
   amount columns being varchar instead of decimal).

   Checking first for anything that won't convert cleanly before 
   changing the column type, same approach as before — don't want to 
   alter the table blind and find out later something broke.
*/

-- Should come back empty. If it doesn't, look at what's in these rows 
-- before converting — could be blanks, typos, or a weird date format.
SELECT topup_date
FROM [unbanked lending trust].[dbo].[airtime_topup_history]
WHERE TRY_CAST(topup_date AS DATE) IS NULL
  AND topup_date IS NOT NULL;

-- Clean, so converting topup_date from text to an actual DATE type.
ALTER TABLE [unbanked lending trust].[dbo].[airtime_topup_history]
ALTER COLUMN topup_date DATE;

-- Now this should actually work — FORMAT() needs a real date, not text.
-- Counting distinct months someone was active, not just total spend, 
-- since being active across several months says more about reliability 
-- than one big lump of activity.
SELECT
    applicant_id,
    COUNT(DISTINCT FORMAT(topup_date, 'yyyy-MM')) AS active_months
FROM [unbanked lending trust].[dbo].[airtime_topup_history]
GROUP BY applicant_id;

--Adding order by
SELECT
    applicant_id,
    COUNT(DISTINCT FORMAT(topup_date, 'yyyy-MM')) AS active_months
FROM [unbanked lending trust].[dbo].[airtime_topup_history]
GROUP BY applicant_id
ORDER BY active_months DESC;



-- Average transaction size + how many transactions total.
-- Helps tell apart "one big transaction" from "lots of small, steady ones."
SELECT
    applicant_id,
    AVG(amount_ngn) AS avg_topup_amount,
    COUNT(*) AS topup_count
FROM [unbanked lending trust].[dbo].[airtime_topup_history]
GROUP BY applicant_id
ORDER BY topup_count DESC;


-- How "spiky" or unpredictable someone's transaction amounts are.
-- Lower variability = more predictable financial behavior, which is 
-- generally the safer signal for lending.
SELECT
    applicant_id,
    STDEV(amount_ngn) AS amount_stddev,
    AVG(amount_ngn) AS amount_avg,
    STDEV(amount_ngn) / NULLIF(AVG(amount_ngn), 0) AS variability_ratio
FROM [unbanked lending trust].[dbo].[mobile_money_transactions]
GROUP BY applicant_id
ORDER BY variability_ratio ASC;


-- What PERCENTAGE of bills were paid on time (not just the total ₦ 
-- amount of the ones that happened to be on time). This is probably 
-- a stronger signal than the raw amount — paying 9/10 bills on time 
-- says more about reliability than one large on-time payment.
SELECT
    applicant_id,
    COUNT(*) AS total_bills,
    SUM(CASE WHEN payment_status = 'ontime' THEN 1 ELSE 0 END) AS ontime_bills,
    CAST(SUM(CASE WHEN payment_status = 'ontime' THEN 1 ELSE 0 END) AS FLOAT)
        / NULLIF(COUNT(*), 0) * 100 AS ontime_payment_rate_pct
FROM [unbanked lending trust].[dbo].[utility_bill_payments]
GROUP BY applicant_id;


-- Checking the real spelling of payment_status values — ontime_bills 
-- keeps coming back 0, so the filter text probably doesn't match 
-- what's actually stored in the column.
SELECT DISTINCT payment_status
FROM [unbanked lending trust].[dbo].[utility_bill_payments];


/*
   Confirmed the real value is 'On-time' (capital O, hyphen) — not 
   'ontime' like I'd been using everywhere. That typo means every 
   utility on-time query so far, including inside the final score, 
   has been silently returning 0 instead of erroring out.
*/

SELECT
    applicant_id,
    COUNT(*) AS total_bills,
    SUM(CASE WHEN payment_status = 'On-time' THEN 1 ELSE 0 END) AS ontime_bills,
    CAST(SUM(CASE WHEN payment_status = 'On-time' THEN 1 ELSE 0 END) AS FLOAT)
        / NULLIF(COUNT(*), 0) * 100 AS ontime_payment_rate_pct
FROM [unbanked lending trust].[dbo].[utility_bill_payments]
GROUP BY applicant_id
ORDER BY ontime_payment_rate_pct DESC;



-- How recently was this person active? Someone who went quiet a year 
-- ago is a different risk than someone active last week, even if 
-- their totals look the same.
SELECT
    applicant_id,
    MAX(transaction_date) AS last_active_date,
    DATEDIFF(DAY, MAX(transaction_date), GETDATE()) AS days_since_last_activity
FROM [unbanked lending trust].[dbo].[mobile_money_transactions]
GROUP BY applicant_id;




-- Same issue as topup_date — transaction_date is stored as text, and 
-- this error means some value in there can't even be read as a valid 
-- date (not just wrong type, actually broken/unparseable). Checking 
-- which rows are the problem before deciding how to handle them.
SELECT transaction_date
FROM [unbanked lending trust].[dbo].[mobile_money_transactions]
WHERE TRY_CAST(transaction_date AS DATE) IS NULL
  AND transaction_date IS NOT NULL;


  /*
   Using TRY_CONVERT with style 103 to read 
   it correctly; TRY_ so any bad value becomes NULL instead of 
   crashing the query.
*/

SELECT
    applicant_id,
    MAX(TRY_CONVERT(DATE, transaction_date, 103)) AS last_active_date,
    DATEDIFF(DAY, MAX(TRY_CONVERT(DATE, transaction_date, 103)), GETDATE()) AS days_since_last_activity
FROM [unbanked lending trust].[dbo].[mobile_money_transactions]
GROUP BY applicant_id
ORDER BY days_since_last_activity;


-- Utility payments relative to income. ₦20,000 in bills means something 
-- very different for someone earning ₦40,000/month vs ₦2,000,000/month — 
-- raw amounts alone don't capture that.
SELECT
    la.applicant_id,
    la.monthly_income_estimate_ngn,
    u.total_utility_paid,
    CAST(u.total_utility_paid AS FLOAT) / NULLIF(la.monthly_income_estimate_ngn, 0) 
        AS utility_to_income_ratio
FROM [unbanked lending trust].[dbo].[loan_applicants] la
LEFT JOIN utility_summary u ON la.applicant_id = u.applicant_id;

/*
   utility_summary only exists inside the query it's defined in — it's 
   a CTE, not a real table, so it vanishes once that query finishes. 
   Re-defining it here so this income-ratio query can actually use it.
*/

;WITH utility_summary AS (
    SELECT
        applicant_id,
        SUM(amount_paid_ngn) AS total_utility_paid
    FROM [unbanked lending trust].[dbo].[utility_bill_payments]
    WHERE payment_status = 'On-time'
    GROUP BY applicant_id
)

SELECT
    la.applicant_id,
    la.monthly_income_estimate_ngn,
    u.total_utility_paid,
    CAST(u.total_utility_paid AS FLOAT) / NULLIF(la.monthly_income_estimate_ngn, 0) 
        AS utility_to_income_ratio
FROM [unbanked lending trust].[dbo].[loan_applicants] la
LEFT JOIN utility_summary u ON la.applicant_id = u.applicant_id;



-- Checking type + any bad values before converting, same as we've 
-- done for the other amount/date columns stored as text.
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'loan_applicants' AND COLUMN_NAME = 'monthly_income_estimate_ngn';

SELECT monthly_income_estimate_ngn
FROM [unbanked lending trust].[dbo].[loan_applicants]
WHERE TRY_CAST(monthly_income_estimate_ngn AS DECIMAL(18,2)) IS NULL
  AND monthly_income_estimate_ngn IS NOT NULL;


  -- Confirming: these are empty strings, not NULLs — that's why the 
-- earlier check "looked" empty but actually returned 11 rows.
SELECT COUNT(*) AS blank_income_count
FROM [unbanked lending trust].[dbo].[loan_applicants]
WHERE TRIM(monthly_income_estimate_ngn) = '';


-- Empty string isn't a real value — treating it as "unknown income" 
-- (NULL) rather than assuming it means zero.
UPDATE [unbanked lending trust].[dbo].[loan_applicants]
SET monthly_income_estimate_ngn = NULL
WHERE TRIM(monthly_income_estimate_ngn) = '';


--This should now return 0 rows if the blanks were the only problem.
-- Checking the "X rows" count at the bottom of Results this time, not 
-- just eyeballing the grid — that's what caused the earlier mix-up.
SELECT monthly_income_estimate_ngn
FROM [unbanked lending trust].[dbo].[loan_applicants]
WHERE TRY_CAST(monthly_income_estimate_ngn AS DECIMAL(18,2)) IS NULL
  AND monthly_income_estimate_ngn IS NOT NULL;



  -- Clean now, so converting monthly_income_estimate_ngn from text to 
-- a real decimal, consistent with the other amount columns.
  ALTER TABLE [unbanked lending trust].[dbo].[loan_applicants]
ALTER COLUMN monthly_income_estimate_ngn DECIMAL(18,2);



-- monthly_income_estimate_ngn is a real decimal now (converted 
-- earlier), so no TRY_CAST needed here anymore — the fix at the 
-- source column handles it. Utility payments relative to income, 
-- since the same ₦ amount means very different things depending on 
-- how much someone earns.
;WITH utility_summary AS (
    SELECT
        applicant_id,
        SUM(amount_paid_ngn) AS total_utility_paid
    FROM [unbanked lending trust].[dbo].[utility_bill_payments]
    WHERE payment_status = 'On-time'
    GROUP BY applicant_id
)
SELECT
    la.applicant_id,
    la.monthly_income_estimate_ngn,
    u.total_utility_paid,
    CAST(u.total_utility_paid AS FLOAT) / NULLIF(la.monthly_income_estimate_ngn, 0) 
        AS utility_to_income_ratio
FROM [unbanked lending trust].[dbo].[loan_applicants] la
LEFT JOIN utility_summary u ON la.applicant_id = u.applicant_id;




-- Classic lending metric: how big is the requested loan relative to 
-- income? Real lenders lean on this heavily, worth comparing against 
-- the alt-data score later.
SELECT
    applicant_id,
    loan_amount_requested_ngn,
    monthly_income_estimate_ngn,
    CAST(loan_amount_requested_ngn AS FLOAT) / NULLIF(monthly_income_estimate_ngn, 0) 
        AS loan_to_income_ratio
FROM [unbanked lending trust].[dbo].[loan_applicants]
ORDER BY loan_to_income_ratio ;



-- Sanity checks before trusting any of this for scoring:

-- Should be empty — flags any applicant_id that appears more than once
-- in loan_applicants (it should be unique per person).
SELECT applicant_id, COUNT(*) 
FROM [unbanked lending trust].[dbo].[loan_applicants]
GROUP BY applicant_id
HAVING COUNT(*) > 1;

-- Should be empty — negative transaction amounts shouldn't exist here.
SELECT applicant_id, amount_ngn
FROM [unbanked lending trust].[dbo].[mobile_money_transactions]
WHERE amount_ngn < 0;

-- Applicants with literally zero activity anywhere. Worth knowing how 
-- many of these exist — they'll need a default/fallback
/*
   Rebuilding all 4 CTEs here since they don't persist between queries.
   This checks for applicants with ZERO activity across every single 
   alt-data source — no airtime, no mobile money, no on-time utility 
   payments, no market sales. These people would need a fallback/default 
   score later, since there's nothing here to base a score on.
*/

;WITH airtime_summary AS (
    SELECT
        applicant_id,
        SUM(amount_ngn) AS total_airtime_spent
    FROM [unbanked lending trust].[dbo].[airtime_topup_history]
    GROUP BY applicant_id
),

mobile_money_summary AS (
    SELECT
        applicant_id,
        SUM(amount_ngn) AS total_mobile_money_spent
    FROM [unbanked lending trust].[dbo].[mobile_money_transactions]
    GROUP BY applicant_id
),

utility_summary AS (
    SELECT
        applicant_id,
        SUM(amount_paid_ngn) AS total_utility_paid
    FROM [unbanked lending trust].[dbo].[utility_bill_payments]
    WHERE payment_status = 'On-time'
    GROUP BY applicant_id
),

market_summary AS (
    SELECT
        applicant_id,
        SUM(amount_ngn) AS total_market_spent
    FROM [unbanked lending trust].[dbo].[market_trading_records]
    WHERE record_type = 'Sale'
    GROUP BY applicant_id
)

SELECT la.applicant_id
FROM [unbanked lending trust].[dbo].[loan_applicants] la
LEFT JOIN airtime_summary a       ON la.applicant_id = a.applicant_id
LEFT JOIN mobile_money_summary m  ON la.applicant_id = m.applicant_id
LEFT JOIN utility_summary u       ON la.applicant_id = u.applicant_id
LEFT JOIN market_summary mk       ON la.applicant_id = mk.applicant_id
WHERE a.applicant_id IS NULL AND m.applicant_id IS NULL
  AND u.applicant_id IS NULL AND mk.applicant_id IS NULL;

  -- How many alt-data sources does each applicant actually show up in? 
-- Someone with only 1 source is a thinner picture than someone with 
-- activity across all 4 — worth knowing before trusting the score equally.
;WITH airtime_summary AS (
    SELECT DISTINCT applicant_id FROM [unbanked lending trust].[dbo].[airtime_topup_history]
),
mobile_money_summary AS (
    SELECT DISTINCT applicant_id FROM [unbanked lending trust].[dbo].[mobile_money_transactions]
),
utility_summary AS (
    SELECT DISTINCT applicant_id FROM [unbanked lending trust].[dbo].[utility_bill_payments]
    WHERE payment_status = 'On-time'
),
market_summary AS (
    SELECT DISTINCT applicant_id FROM [unbanked lending trust].[dbo].[market_trading_records]
    WHERE record_type = 'Sale'
)

SELECT
    la.applicant_id,
    (CASE WHEN a.applicant_id IS NOT NULL THEN 1 ELSE 0 END
   + CASE WHEN m.applicant_id IS NOT NULL THEN 1 ELSE 0 END
   + CASE WHEN u.applicant_id IS NOT NULL THEN 1 ELSE 0 END
   + CASE WHEN mk.applicant_id IS NOT NULL THEN 1 ELSE 0 END) AS sources_present
FROM [unbanked lending trust].[dbo].[loan_applicants] la
LEFT JOIN airtime_summary a       ON la.applicant_id = a.applicant_id
LEFT JOIN mobile_money_summary m  ON la.applicant_id = m.applicant_id
LEFT JOIN utility_summary u       ON la.applicant_id = u.applicant_id
LEFT JOIN market_summary mk       ON la.applicant_id = mk.applicant_id
ORDER BY sources_present ASC;


/*
   Alt-data credit score, ranked WITHIN sources_present groups instead 
   of head-to-head across everyone. A 1-source applicant only has 15% 
   or 30% (whichever single category they have) of the score to work 
   with, since the other categories are forced to 0 — comparing them 
   directly against someone with all 4 sources isn't fair, it 
   penalizes thin data, not low creditworthiness. This way, someone is 
   only ranked against others with the same amount of data available.
*/

;WITH airtime_summary AS (
    SELECT
        applicant_id,
        SUM(amount_ngn) AS total_airtime_spent
    FROM [unbanked lending trust].[dbo].[airtime_topup_history]
    GROUP BY applicant_id
),

mobile_money_summary AS (
    SELECT
        applicant_id,
        SUM(amount_ngn) AS total_mobile_money_spent
    FROM [unbanked lending trust].[dbo].[mobile_money_transactions]
    GROUP BY applicant_id
),

utility_summary AS (
    SELECT
        applicant_id,
        SUM(amount_paid_ngn) AS total_utility_paid
    FROM [unbanked lending trust].[dbo].[utility_bill_payments]
    WHERE payment_status = 'On-time'
    GROUP BY applicant_id
),

market_summary AS (
    SELECT
        applicant_id,
        SUM(amount_ngn) AS total_market_spent
    FROM [unbanked lending trust].[dbo].[market_trading_records]
    WHERE record_type = 'Sale'
    GROUP BY applicant_id
),

combined AS (
    SELECT
        la.applicant_id,
        la.full_name,
        la.credit_bureau_score,
        ISNULL(a.total_airtime_spent, 0)      AS total_airtime_spent,
        ISNULL(m.total_mobile_money_spent, 0) AS total_mobile_money_spent,
        ISNULL(u.total_utility_paid, 0)       AS total_utility_paid,
        ISNULL(mk.total_market_spent, 0)      AS total_market_spent,

        -- counting how many of the 4 sources this applicant actually has
        (CASE WHEN a.applicant_id IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN m.applicant_id IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN u.applicant_id IS NOT NULL THEN 1 ELSE 0 END
       + CASE WHEN mk.applicant_id IS NOT NULL THEN 1 ELSE 0 END) AS sources_present

    FROM [unbanked lending trust].[dbo].[loan_applicants] la
    LEFT JOIN airtime_summary a       ON la.applicant_id = a.applicant_id
    LEFT JOIN mobile_money_summary m  ON la.applicant_id = m.applicant_id
    LEFT JOIN utility_summary u       ON la.applicant_id = u.applicant_id
    LEFT JOIN market_summary mk       ON la.applicant_id = mk.applicant_id
),

normalized AS (
    SELECT
        applicant_id,
        full_name,
        credit_bureau_score,
        sources_present,
        total_airtime_spent,
        total_mobile_money_spent,
        total_utility_paid,
        total_market_spent,

        CAST(
            (total_airtime_spent - MIN(total_airtime_spent) OVER ())
            * 100.0
            / NULLIF(MAX(total_airtime_spent) OVER () - MIN(total_airtime_spent) OVER (), 0)
        AS DECIMAL(6,2)) AS airtime_score,

        CAST(
            (total_mobile_money_spent - MIN(total_mobile_money_spent) OVER ())
            * 100.0
            / NULLIF(MAX(total_mobile_money_spent) OVER () - MIN(total_mobile_money_spent) OVER (), 0)
        AS DECIMAL(6,2)) AS mobile_money_score,

        CAST(
            (total_utility_paid - MIN(total_utility_paid) OVER ())
            * 100.0
            / NULLIF(MAX(total_utility_paid) OVER () - MIN(total_utility_paid) OVER (), 0)
        AS DECIMAL(6,2)) AS utility_score,

        CAST(
            (total_market_spent - MIN(total_market_spent) OVER ())
            * 100.0
            / NULLIF(MAX(total_market_spent) OVER () - MIN(total_market_spent) OVER (), 0)
        AS DECIMAL(6,2)) AS market_score

    FROM combined
),

scored AS (
    SELECT
        applicant_id,
        full_name,
        credit_bureau_score,
        sources_present,
        total_airtime_spent,
        total_mobile_money_spent,
        total_utility_paid,
        total_market_spent,
        airtime_score,
        mobile_money_score,
        utility_score,
        market_score,

        CAST(
            ISNULL(utility_score, 0)       * 0.35
          + ISNULL(mobile_money_score, 0)  * 0.30
          + ISNULL(market_score, 0)        * 0.20
          + ISNULL(airtime_score, 0)       * 0.15
        AS DECIMAL(6,2)) AS alt_data_credit_score

    FROM normalized
)

SELECT
    applicant_id,
    full_name,
    credit_bureau_score,
    sources_present,
    alt_data_credit_score,

    -- rank restarts at 1 for each sources_present group, so a 1-source 
    -- applicant is only compared against other 1-source applicants
    RANK() OVER (PARTITION BY sources_present ORDER BY alt_data_credit_score DESC) 
        AS rank_within_group

FROM scored
ORDER BY sources_present DESC, rank_within_group ASC;


/*
   loan_status only reflects whether the loan APPLICATION was approved, 
   not whether it was ever repaid — there's no repayment-outcome table 
   in this database, so we can't validate against actual repayment.

   This instead checks whether the alt-data score lines up with existing 
   approval decisions. Not proof the score predicts repayment — just 
   whether it agrees with who's already getting approved. Worth being 
   upfront about this distinction when writing this project up.
*/

;WITH airtime_summary AS (
    SELECT applicant_id, SUM(amount_ngn) AS total_airtime_spent
    FROM [unbanked lending trust].[dbo].[airtime_topup_history]
    GROUP BY applicant_id
),
mobile_money_summary AS (
    SELECT applicant_id, SUM(amount_ngn) AS total_mobile_money_spent
    FROM [unbanked lending trust].[dbo].[mobile_money_transactions]
    GROUP BY applicant_id
),
utility_summary AS (
    SELECT applicant_id, SUM(amount_paid_ngn) AS total_utility_paid
    FROM [unbanked lending trust].[dbo].[utility_bill_payments]
    WHERE payment_status = 'On-time'
    GROUP BY applicant_id
),
market_summary AS (
    SELECT applicant_id, SUM(amount_ngn) AS total_market_spent
    FROM [unbanked lending trust].[dbo].[market_trading_records]
    WHERE record_type = 'Sale'
    GROUP BY applicant_id
),
combined AS (
    SELECT
        la.applicant_id,
        la.loan_status,
        ISNULL(a.total_airtime_spent, 0)      AS total_airtime_spent,
        ISNULL(m.total_mobile_money_spent, 0) AS total_mobile_money_spent,
        ISNULL(u.total_utility_paid, 0)       AS total_utility_paid,
        ISNULL(mk.total_market_spent, 0)      AS total_market_spent
    FROM [unbanked lending trust].[dbo].[loan_applicants] la
    LEFT JOIN airtime_summary a       ON la.applicant_id = a.applicant_id
    LEFT JOIN mobile_money_summary m  ON la.applicant_id = m.applicant_id
    LEFT JOIN utility_summary u       ON la.applicant_id = u.applicant_id
    LEFT JOIN market_summary mk       ON la.applicant_id = mk.applicant_id
),
normalized AS (
    SELECT
        applicant_id,
        loan_status,
        CAST((total_airtime_spent - MIN(total_airtime_spent) OVER ()) * 100.0
            / NULLIF(MAX(total_airtime_spent) OVER () - MIN(total_airtime_spent) OVER (), 0)
        AS DECIMAL(6,2)) AS airtime_score,
        CAST((total_mobile_money_spent - MIN(total_mobile_money_spent) OVER ()) * 100.0
            / NULLIF(MAX(total_mobile_money_spent) OVER () - MIN(total_mobile_money_spent) OVER (), 0)
        AS DECIMAL(6,2)) AS mobile_money_score,
        CAST((total_utility_paid - MIN(total_utility_paid) OVER ()) * 100.0
            / NULLIF(MAX(total_utility_paid) OVER () - MIN(total_utility_paid) OVER (), 0)
        AS DECIMAL(6,2)) AS utility_score,
        CAST((total_market_spent - MIN(total_market_spent) OVER ()) * 100.0
            / NULLIF(MAX(total_market_spent) OVER () - MIN(total_market_spent) OVER (), 0)
        AS DECIMAL(6,2)) AS market_score
    FROM combined
),
scored AS (
    SELECT
        applicant_id,
        loan_status,
        CAST(
            ISNULL(utility_score, 0)       * 0.35
          + ISNULL(mobile_money_score, 0)  * 0.30
          + ISNULL(market_score, 0)        * 0.20
          + ISNULL(airtime_score, 0)       * 0.15
        AS DECIMAL(6,2)) AS alt_data_credit_score
    FROM normalized
),
tiered AS (
    SELECT
        *,
        CASE
            WHEN alt_data_credit_score < 20 THEN '0-20'
            WHEN alt_data_credit_score < 40 THEN '20-40'
            WHEN alt_data_credit_score < 60 THEN '40-60'
            WHEN alt_data_credit_score < 80 THEN '60-80'
            ELSE '80-100'
        END AS score_tier
    FROM scored
)

SELECT
    score_tier,
    COUNT(*) AS total_applicants,
    SUM(CASE WHEN loan_status = 'Approved' THEN 1 ELSE 0 END) AS approved_count,
    CAST(SUM(CASE WHEN loan_status = 'Approved' THEN 1 ELSE 0 END) AS FLOAT)
        / NULLIF(COUNT(*), 0) * 100 AS approval_rate_pct
FROM tiered
GROUP BY score_tier
ORDER BY score_tier;


-- Just checking the raw score distribution, no approval comparison yet
/*
   Checking the raw score distribution directly, before comparing 
   against approval rates again — need to understand why nobody's 
   scoring above 60 in the tier breakdown.
*/

;WITH airtime_summary AS (
    SELECT applicant_id, SUM(amount_ngn) AS total_airtime_spent
    FROM [unbanked lending trust].[dbo].[airtime_topup_history]
    GROUP BY applicant_id
),
mobile_money_summary AS (
    SELECT applicant_id, SUM(amount_ngn) AS total_mobile_money_spent
    FROM [unbanked lending trust].[dbo].[mobile_money_transactions]
    GROUP BY applicant_id
),
utility_summary AS (
    SELECT applicant_id, SUM(amount_paid_ngn) AS total_utility_paid
    FROM [unbanked lending trust].[dbo].[utility_bill_payments]
    WHERE payment_status = 'On-time'
    GROUP BY applicant_id
),
market_summary AS (
    SELECT applicant_id, SUM(amount_ngn) AS total_market_spent
    FROM [unbanked lending trust].[dbo].[market_trading_records]
    WHERE record_type = 'Sale'
    GROUP BY applicant_id
),
combined AS (
    SELECT
        la.applicant_id,
        la.loan_status,
        ISNULL(a.total_airtime_spent, 0)      AS total_airtime_spent,
        ISNULL(m.total_mobile_money_spent, 0) AS total_mobile_money_spent,
        ISNULL(u.total_utility_paid, 0)       AS total_utility_paid,
        ISNULL(mk.total_market_spent, 0)      AS total_market_spent
    FROM [unbanked lending trust].[dbo].[loan_applicants] la
    LEFT JOIN airtime_summary a       ON la.applicant_id = a.applicant_id
    LEFT JOIN mobile_money_summary m  ON la.applicant_id = m.applicant_id
    LEFT JOIN utility_summary u       ON la.applicant_id = u.applicant_id
    LEFT JOIN market_summary mk       ON la.applicant_id = mk.applicant_id
),
normalized AS (
    SELECT
        applicant_id,
        loan_status,
        CAST((total_airtime_spent - MIN(total_airtime_spent) OVER ()) * 100.0
            / NULLIF(MAX(total_airtime_spent) OVER () - MIN(total_airtime_spent) OVER (), 0)
        AS DECIMAL(6,2)) AS airtime_score,
        CAST((total_mobile_money_spent - MIN(total_mobile_money_spent) OVER ()) * 100.0
            / NULLIF(MAX(total_mobile_money_spent) OVER () - MIN(total_mobile_money_spent) OVER (), 0)
        AS DECIMAL(6,2)) AS mobile_money_score,
        CAST((total_utility_paid - MIN(total_utility_paid) OVER ()) * 100.0
            / NULLIF(MAX(total_utility_paid) OVER () - MIN(total_utility_paid) OVER (), 0)
        AS DECIMAL(6,2)) AS utility_score,
        CAST((total_market_spent - MIN(total_market_spent) OVER ()) * 100.0
            / NULLIF(MAX(total_market_spent) OVER () - MIN(total_market_spent) OVER (), 0)
        AS DECIMAL(6,2)) AS market_score
    FROM combined
),
scored AS (
    SELECT
        applicant_id,
        loan_status,
        airtime_score,
        mobile_money_score,
        utility_score,
        market_score,
        CAST(
            ISNULL(utility_score, 0)       * 0.35
          + ISNULL(mobile_money_score, 0)  * 0.30
          + ISNULL(market_score, 0)        * 0.20
          + ISNULL(airtime_score, 0)       * 0.15
        AS DECIMAL(6,2)) AS alt_data_credit_score
    FROM normalized
)

SELECT
    MIN(alt_data_credit_score) AS min_score,
    MAX(alt_data_credit_score) AS max_score,
    AVG(alt_data_credit_score) AS avg_score
FROM scored;


/*
   Fix for the scoring range problem: original alt_data_credit_score 
   only ever reached 0.25–54.23, not the intended 0–100 — because 
   hitting 100 would require someone to be the single top spender in 
   ALL 4 categories at once, which almost never happens.

   Adding one more step that re-normalizes the composite score itself, 
   stretching the real range back out to 0–100. Then re-running the 
   tier vs. approval-rate check on this rescaled version to see if the 
   pattern looks any different once the full scale is actually used.
*/

;WITH airtime_summary AS (
    SELECT applicant_id, SUM(amount_ngn) AS total_airtime_spent
    FROM [unbanked lending trust].[dbo].[airtime_topup_history]
    GROUP BY applicant_id
),
mobile_money_summary AS (
    SELECT applicant_id, SUM(amount_ngn) AS total_mobile_money_spent
    FROM [unbanked lending trust].[dbo].[mobile_money_transactions]
    GROUP BY applicant_id
),
utility_summary AS (
    SELECT applicant_id, SUM(amount_paid_ngn) AS total_utility_paid
    FROM [unbanked lending trust].[dbo].[utility_bill_payments]
    WHERE payment_status = 'On-time'
    GROUP BY applicant_id
),
market_summary AS (
    SELECT applicant_id, SUM(amount_ngn) AS total_market_spent
    FROM [unbanked lending trust].[dbo].[market_trading_records]
    WHERE record_type = 'Sale'
    GROUP BY applicant_id
),
combined AS (
    SELECT
        la.applicant_id,
        la.loan_status,
        ISNULL(a.total_airtime_spent, 0)      AS total_airtime_spent,
        ISNULL(m.total_mobile_money_spent, 0) AS total_mobile_money_spent,
        ISNULL(u.total_utility_paid, 0)       AS total_utility_paid,
        ISNULL(mk.total_market_spent, 0)      AS total_market_spent
    FROM [unbanked lending trust].[dbo].[loan_applicants] la
    LEFT JOIN airtime_summary a       ON la.applicant_id = a.applicant_id
    LEFT JOIN mobile_money_summary m  ON la.applicant_id = m.applicant_id
    LEFT JOIN utility_summary u       ON la.applicant_id = u.applicant_id
    LEFT JOIN market_summary mk       ON la.applicant_id = mk.applicant_id
),
normalized AS (
    SELECT
        applicant_id,
        loan_status,
        CAST((total_airtime_spent - MIN(total_airtime_spent) OVER ()) * 100.0
            / NULLIF(MAX(total_airtime_spent) OVER () - MIN(total_airtime_spent) OVER (), 0)
        AS DECIMAL(6,2)) AS airtime_score,
        CAST((total_mobile_money_spent - MIN(total_mobile_money_spent) OVER ()) * 100.0
            / NULLIF(MAX(total_mobile_money_spent) OVER () - MIN(total_mobile_money_spent) OVER (), 0)
        AS DECIMAL(6,2)) AS mobile_money_score,
        CAST((total_utility_paid - MIN(total_utility_paid) OVER ()) * 100.0
            / NULLIF(MAX(total_utility_paid) OVER () - MIN(total_utility_paid) OVER (), 0)
        AS DECIMAL(6,2)) AS utility_score,
        CAST((total_market_spent - MIN(total_market_spent) OVER ()) * 100.0
            / NULLIF(MAX(total_market_spent) OVER () - MIN(total_market_spent) OVER (), 0)
        AS DECIMAL(6,2)) AS market_score
    FROM combined
),
scored AS (
    SELECT
        applicant_id,
        loan_status,
        CAST(
            ISNULL(utility_score, 0)       * 0.35
          + ISNULL(mobile_money_score, 0)  * 0.30
          + ISNULL(market_score, 0)        * 0.20
          + ISNULL(airtime_score, 0)       * 0.15
        AS DECIMAL(6,2)) AS alt_data_credit_score
    FROM normalized
),
rescaled AS (
    SELECT
        applicant_id,
        loan_status,
        alt_data_credit_score,
        CAST(
            (alt_data_credit_score - MIN(alt_data_credit_score) OVER ())
            * 100.0
            / NULLIF(MAX(alt_data_credit_score) OVER () - MIN(alt_data_credit_score) OVER (), 0)
        AS DECIMAL(6,2)) AS alt_data_credit_score_rescaled
    FROM scored
),
tiered AS (
    SELECT
        *,
        CASE
            WHEN alt_data_credit_score_rescaled < 20 THEN '0-20'
            WHEN alt_data_credit_score_rescaled < 40 THEN '20-40'
            WHEN alt_data_credit_score_rescaled < 60 THEN '40-60'
            WHEN alt_data_credit_score_rescaled < 80 THEN '60-80'
            ELSE '80-100'
        END AS score_tier
    FROM rescaled
)

SELECT
    score_tier,
    COUNT(*) AS total_applicants,
    SUM(CASE WHEN loan_status = 'Approved' THEN 1 ELSE 0 END) AS approved_count,
    CAST(SUM(CASE WHEN loan_status = 'Approved' THEN 1 ELSE 0 END) AS FLOAT)
        / NULLIF(COUNT(*), 0) * 100 AS approval_rate_pct
FROM tiered
GROUP BY score_tier
ORDER BY score_tier;




  


--CONVERT THE 3RD ONE 
ALTER TABLE [unbanked lending trust].[dbo].[utility_bill_payments]
ALTER COLUMN amount_paid_ngn DECIMAL(18,2);


--0 PEOPLE MATCHED THE CRITERIA SO WE SWITCHED TO THIS
;WITH airtime_summary AS (
    SELECT
        applicant_id,
        SUM(amount_ngn) AS total_airtime_spent
    FROM [unbanked lending trust].[dbo].[airtime_topup_history]
    GROUP BY applicant_id
),

mobile_money_summary AS (
    SELECT
        applicant_id,
        SUM(amount_ngn) AS total_mobile_money_spent
    FROM [unbanked lending trust].[dbo].[mobile_money_transactions]
    GROUP BY applicant_id
),

utility_summary AS (
    SELECT
        applicant_id,
        SUM(amount_paid_ngn) AS total_utility_paid
    FROM [unbanked lending trust].[dbo].[utility_bill_payments]
    WHERE payment_status = 'ontime'
    GROUP BY applicant_id
),

market_summary AS (
    SELECT
        applicant_id,
        SUM(amount_ngn) AS total_market_spent
    FROM [unbanked lending trust].[dbo].[market_trading_records]
    WHERE record_type = 'Sale'
    GROUP BY applicant_id
)

SELECT
    la.applicant_id,
    la.full_name,
    la.age,
    la.occupation_type,
    la.monthly_income_estimate_ngn,
    la.credit_bureau_score,
    la.loan_amount_requested_ngn,
    la.loan_purpose,
    la.loan_status,
    ISNULL(a.total_airtime_spent, 0)      AS total_airtime_spent,
    ISNULL(m.total_mobile_money_spent, 0) AS total_mobile_money_spent,
    ISNULL(u.total_utility_paid, 0)       AS total_utility_paid,
    ISNULL(mk.total_market_spent, 0)      AS total_market_spent,
    ISNULL(a.total_airtime_spent, 0)
        + ISNULL(m.total_mobile_money_spent, 0)
        + ISNULL(u.total_utility_paid, 0)
        + ISNULL(mk.total_market_spent, 0) AS total_money_spent
FROM [unbanked lending trust].[dbo].[loan_applicants] la
LEFT JOIN airtime_summary a       ON la.applicant_id = a.applicant_id
LEFT JOIN mobile_money_summary m  ON la.applicant_id = m.applicant_id
LEFT JOIN utility_summary u       ON la.applicant_id = u.applicant_id
LEFT JOIN market_summary mk       ON la.applicant_id = mk.applicant_id
ORDER BY
    la.credit_bureau_score DESC,
    mk.total_market_spent DESC,
    u.total_utility_paid DESC,
    m.total_mobile_money_spent DESC,
    a.total_airtime_spent DESC;




--ALT-DATA CREDIT SCORE — v1 (Heuristic, Not Yet Validated)
  ------------------------------------------------------------
   --This score combines 4 alternative data sources (airtime, mobile 
   --money, utility payments, market sales) into a single 0–100 
   --composite using min-max normalization and manually assigned weights.

   ;WITH airtime_summary AS (
    SELECT
        applicant_id,
        SUM(amount_ngn) AS total_airtime_spent
    FROM [unbanked lending trust].[dbo].[airtime_topup_history]
    GROUP BY applicant_id
),

mobile_money_summary AS (
    SELECT
        applicant_id,
        SUM(amount_ngn) AS total_mobile_money_spent
    FROM [unbanked lending trust].[dbo].[mobile_money_transactions]
    GROUP BY applicant_id
),

utility_summary AS (
    SELECT
        applicant_id,
        SUM(amount_paid_ngn) AS total_utility_paid
    FROM [unbanked lending trust].[dbo].[utility_bill_payments]
    WHERE payment_status = 'On-time'
    GROUP BY applicant_id
),

market_summary AS (
    SELECT
        applicant_id,
        SUM(amount_ngn) AS total_market_spent
    FROM [unbanked lending trust].[dbo].[market_trading_records]
    WHERE record_type = 'Sale'
    GROUP BY applicant_id
),

combined AS (
    SELECT
        la.applicant_id,
        la.full_name,
        la.credit_bureau_score,
        ISNULL(a.total_airtime_spent, 0)      AS total_airtime_spent,
        ISNULL(m.total_mobile_money_spent, 0) AS total_mobile_money_spent,
        ISNULL(u.total_utility_paid, 0)       AS total_utility_paid,
        ISNULL(mk.total_market_spent, 0)      AS total_market_spent
    FROM [unbanked lending trust].[dbo].[loan_applicants] la
    LEFT JOIN airtime_summary a       ON la.applicant_id = a.applicant_id
    LEFT JOIN mobile_money_summary m  ON la.applicant_id = m.applicant_id
    LEFT JOIN utility_summary u       ON la.applicant_id = u.applicant_id
    LEFT JOIN market_summary mk       ON la.applicant_id = mk.applicant_id
),

normalized AS (
    SELECT
        applicant_id,
        full_name,
        credit_bureau_score,
        total_airtime_spent,
        total_mobile_money_spent,
        total_utility_paid,
        total_market_spent,

        -- Min-max normalization: (value - min) / (max - min), scaled 0 to 100
        CAST(
            (total_airtime_spent - MIN(total_airtime_spent) OVER ())
            * 100.0
            / NULLIF(MAX(total_airtime_spent) OVER () - MIN(total_airtime_spent) OVER (), 0)
        AS DECIMAL(6,2)) AS airtime_score,

        CAST(
            (total_mobile_money_spent - MIN(total_mobile_money_spent) OVER ())
            * 100.0
            / NULLIF(MAX(total_mobile_money_spent) OVER () - MIN(total_mobile_money_spent) OVER (), 0)
        AS DECIMAL(6,2)) AS mobile_money_score,

        CAST(
            (total_utility_paid - MIN(total_utility_paid) OVER ())
            * 100.0
            / NULLIF(MAX(total_utility_paid) OVER () - MIN(total_utility_paid) OVER (), 0)
        AS DECIMAL(6,2)) AS utility_score,

        CAST(
            (total_market_spent - MIN(total_market_spent) OVER ())
            * 100.0
            / NULLIF(MAX(total_market_spent) OVER () - MIN(total_market_spent) OVER (), 0)
        AS DECIMAL(6,2)) AS market_score

    FROM combined
)

SELECT
    applicant_id,
    full_name,
    credit_bureau_score,
    total_airtime_spent,
    total_mobile_money_spent,
    total_utility_paid,
    total_market_spent,
    airtime_score,
    mobile_money_score,
    utility_score,
    market_score,

    -- Weighted composite: adjust these weights based on domain judgment
    -- (utility payment reliability weighted highest as a proxy for financial discipline)
    CAST(
        ISNULL(utility_score, 0)       * 0.35
      + ISNULL(mobile_money_score, 0)  * 0.30
      + ISNULL(market_score, 0)        * 0.20
      + ISNULL(airtime_score, 0)       * 0.15
    AS DECIMAL(6,2)) AS alt_data_credit_score

FROM normalized
ORDER BY alt_data_credit_score DESC;

/*
   ============================================================
   Trusting the Unbanked — Alt-Data Credit Scoring
   ============================================================
   IMPORTANT LIMITATION: loan_status (Approved/Pending/Rejected) 
   in this dataset was synthetically generated with no built-in 
   relationship to the alt-data fields below (airtime, mobile 
   money, utility payments, market sales). There is also no 
   repayment-outcome table in this database.

   That means the validation section near the end of this script 
   checks whether the alt-data score aligns with EXISTING approval 
   decisions — not whether it predicts actual repayment. Results 
   showed no consistent trend, which is an honest and expected 
   outcome given the synthetic labels aren't causally tied to the 
   inputs. This script demonstrates the SQL pipeline and scoring 
   methodology, not a validated predictive model.
*/
