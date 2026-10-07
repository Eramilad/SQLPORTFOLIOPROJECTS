/* ============================================================================
   FRAUD RISK-SIGNAL ANALYSIS & CUSTOMER SEGMENTATION
   ============================================================================
   Purpose:
     Identify which transaction/login attributes actually correlate with
     fraud, quantify how strong each signal is, and segment customers into
     risk tiers based on real historical behavior. This is the evidence
     base for deciding WHERE to add authentication friction -- the
     strategic recommendation that precedes any engineering build.

   Assumed table: transactions
     transaction_id                 TEXT / VARCHAR, primary key
     customer_id                    TEXT / VARCHAR
     timestamp                      DATETIME / TIMESTAMP
     transaction_amount             NUMERIC / DECIMAL
     account_age_days               INT
     device_id                      TEXT / VARCHAR
     is_new_device                  BOOLEAN
     is_new_location                BOOLEAN
     country_code                   TEXT / VARCHAR(2)
     failed_login_attempts          INT
     payment_method                 TEXT / VARCHAR
     shipping_billing_mismatch      BOOLEAN
     time_since_last_purchase_days  INT
     is_fraud                       BOOLEAN   -- or chargeback_flag; see note below

   Engine notes:
     Written primarily in PostgreSQL syntax. Where another major engine
     (MySQL, SQL Server) needs different syntax, an alternative is given
     in a comment directly below the relevant query.

   IMPORTANT CAVEAT (read before trusting any output):
     - If is_fraud and chargeback_flag are different columns in your actual
       data, confirm which one you're using -- chargebacks can land 60-90
       days after the transaction, which can distort time-of-day patterns.
     - Every rate below should be read alongside its row count. A rate from
       a segment with under ~30-50 transactions is not reliable -- noise,
       not signal.
     - This script produces rule-based, explainable risk scoring suitable
       for a business/strategy pitch. It is NOT a predictive fraud model.
       A real ML model (logistic regression, gradient boosting) is a
       separate, harder deliverable.
   ============================================================================ */


/* ============================================================================
   SECTION 1: BASELINE -- overall fraud rate
   ----------------------------------------------------------------------------
   Run this first. Every "lift" and tier threshold later in this script is
   measured against this number, so get it before anything else.
   ============================================================================ */

SELECT
    COUNT(*)                                            AS total_transactions,
    SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END)            AS total_fraud_cases,
    ROUND(
        100.0 * SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END) / COUNT(*)
    , 2)                                                  AS overall_fraud_rate_pct
FROM transactions;


/* ============================================================================
   SECTION 2: SINGLE-SIGNAL FRAUD RATES
   ----------------------------------------------------------------------------
   Checks each individual risk flag in isolation, before combining them.
   This establishes which signals are even worth including in a composite
   score -- a flag with no rate difference from baseline isn't useful.
   ============================================================================ */

-- 2a. New device
SELECT
    is_new_device,
    COUNT(*)                                            AS total_txns,
    SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END)            AS fraud_count,
    ROUND(100.0 * SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
GROUP BY is_new_device;

-- 2b. New location
SELECT
    is_new_location,
    COUNT(*)                                            AS total_txns,
    SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END)            AS fraud_count,
    ROUND(100.0 * SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
GROUP BY is_new_location;

-- 2c. Shipping/billing mismatch
SELECT
    shipping_billing_mismatch,
    COUNT(*)                                            AS total_txns,
    SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END)            AS fraud_count,
    ROUND(100.0 * SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
GROUP BY shipping_billing_mismatch;

-- 2d. Failed login attempts (bucketed)
SELECT
    failed_login_attempts,
    COUNT(*)                                            AS total_txns,
    SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END)            AS fraud_count,
    ROUND(100.0 * SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
GROUP BY failed_login_attempts
ORDER BY failed_login_attempts;

-- 2e. Transaction amount bucket
SELECT
    CASE
        WHEN transaction_amount >= 500 THEN 'high (>=500)'
        WHEN transaction_amount >= 100 THEN 'medium (100-499)'
        ELSE 'low (<100)'
    END                                                  AS amount_bucket,
    COUNT(*)                                            AS total_txns,
    SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END)            AS fraud_count,
    ROUND(100.0 * SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
GROUP BY
    CASE
        WHEN transaction_amount >= 500 THEN 'high (>=500)'
        WHEN transaction_amount >= 100 THEN 'medium (100-499)'
        ELSE 'low (<100)'
    END
ORDER BY fraud_rate_pct DESC;

-- 2f. Account age bucket
SELECT
    CASE
        WHEN account_age_days < 14  THEN 'brand_new (<14d)'
        WHEN account_age_days < 60  THEN 'new (14-59d)'
        WHEN account_age_days < 180 THEN 'established (60-179d)'
        ELSE 'loyal (180d+)'
    END                                                  AS account_age_bucket,
    COUNT(*)                                            AS total_txns,
    SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END)            AS fraud_count,
    ROUND(100.0 * SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
GROUP BY
    CASE
        WHEN account_age_days < 14  THEN 'brand_new (<14d)'
        WHEN account_age_days < 60  THEN 'new (14-59d)'
        WHEN account_age_days < 180 THEN 'established (60-179d)'
        ELSE 'loyal (180d+)'
    END
ORDER BY fraud_rate_pct DESC;


/* ============================================================================
   SECTION 3: LIFT -- how much MORE likely than baseline
   ----------------------------------------------------------------------------
   Raw fraud-rate percentages are hard to compare across signals of
   different base frequencies. Lift (segment rate / overall rate) tells you
   how informative a signal actually is: lift of 1.0 = no better than
   guessing; lift of 3.0 = 3x riskier than an average transaction.
   ============================================================================ */

WITH baseline AS (
    SELECT AVG(CASE WHEN is_fraud THEN 1.0 ELSE 0 END) AS overall_fraud_rate
    FROM transactions
)
SELECT
    failed_login_attempts,
    COUNT(*)                                             AS total_txns,
    ROUND(AVG(CASE WHEN is_fraud THEN 1.0 ELSE 0 END), 4) AS segment_fraud_rate,
    ROUND(
        AVG(CASE WHEN is_fraud THEN 1.0 ELSE 0 END)
        / (SELECT overall_fraud_rate FROM baseline)
    , 2)                                                   AS lift
FROM transactions
GROUP BY failed_login_attempts
ORDER BY lift DESC;

-- Same pattern can be reused for any other single signal or bucket by
-- swapping the GROUP BY column -- e.g. is_new_device, amount_bucket, etc.


/* ============================================================================
   SECTION 4: COMBINED-SIGNAL FRAUD RATES
   ----------------------------------------------------------------------------
   This is the core "evidence base" query: it shows how fraud rate changes
   when multiple risk signals co-occur, which is what actually drives a
   friction recommendation (single signals in isolation usually overstate
   or understate the real risk).
   ============================================================================ */

SELECT
    is_new_device,
    is_new_location,
    CASE WHEN transaction_amount >= 500 THEN 'high' ELSE 'normal' END AS amount_bucket,
    COUNT(*)                                            AS total_txns,
    SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END)            AS fraud_count,
    ROUND(100.0 * SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
GROUP BY
    is_new_device,
    is_new_location,
    CASE WHEN transaction_amount >= 500 THEN 'high' ELSE 'normal' END
-- Keep an eye on total_txns here -- a 100% fraud_rate_pct on 2 transactions
-- is noise, not a pattern. Treat any bucket under ~30 rows with caution.
ORDER BY fraud_rate_pct DESC;


/* ============================================================================
   SECTION 5: TIME-OF-DAY PATTERNS
   ----------------------------------------------------------------------------
   5a. Global hour-of-day fraud rate (quick first look).
   5b. Customer-specific "unusual hour" flag (more rigorous -- a 2am
       transaction is unusual for most people but normal for a shift
       worker, so personalize the baseline per customer where you have
       enough history to do so).
   ============================================================================ */

-- 5a. Global pattern
SELECT
    EXTRACT(HOUR FROM timestamp)                        AS txn_hour,
    COUNT(*)                                            AS total_txns,
    SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END)            AS fraud_count,
    ROUND(100.0 * SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM transactions
GROUP BY EXTRACT(HOUR FROM timestamp)
ORDER BY txn_hour;
-- MySQL:      replace EXTRACT(HOUR FROM timestamp) with HOUR(timestamp)
-- SQL Server: replace with DATEPART(HOUR, timestamp)

-- 5b. Customer-specific unusual-hour flag (PostgreSQL syntax)
-- Only meaningful for customers with enough transaction history (filter
-- applied in CTE below -- adjust the minimum as your data allows).
WITH customer_hour_counts AS (
    SELECT
        customer_id,
        EXTRACT(HOUR FROM timestamp) AS txn_hour,
        COUNT(*)                     AS txns_at_hour
    FROM transactions
    GROUP BY customer_id, EXTRACT(HOUR FROM timestamp)
),
customer_txn_totals AS (
    SELECT customer_id, COUNT(*) AS total_txns
    FROM transactions
    GROUP BY customer_id
    HAVING COUNT(*) >= 5   -- minimum history required to personalize
),
customer_typical_hours AS (
    SELECT
        c.customer_id,
        ARRAY_AGG(c.txn_hour ORDER BY c.txns_at_hour DESC) AS ranked_hours
    FROM customer_hour_counts c
    INNER JOIN customer_txn_totals t ON c.customer_id = t.customer_id
    GROUP BY c.customer_id
)
SELECT
    t.transaction_id,
    t.customer_id,
    EXTRACT(HOUR FROM t.timestamp) AS txn_hour,
    CASE
        WHEN c.ranked_hours IS NULL THEN 'insufficient_history'
        WHEN EXTRACT(HOUR FROM t.timestamp) = ANY(c.ranked_hours[1:3])
            THEN 'typical_hour'
        ELSE 'unusual_hour'
    END AS hour_flag
FROM transactions t
LEFT JOIN customer_typical_hours c ON t.customer_id = c.customer_id;
-- No native array/ranking equivalent in MySQL/SQL Server -- would need a
-- window-function rewrite (ROW_NUMBER() OVER (...)) for those engines.


/* ============================================================================
   SECTION 6: RECENCY SIGNAL -- days since last purchase
   ----------------------------------------------------------------------------
   Uses a window function to compute gap-since-last-transaction per
   customer directly from timestamp, rather than relying on a
   pre-computed column (useful if time_since_last_purchase_days wasn't
   supplied or needs validation).
   ============================================================================ */

SELECT
    transaction_id,
    customer_id,
    timestamp,
    DATEDIFF(
        day,
        LAG(timestamp) OVER (PARTITION BY customer_id ORDER BY timestamp),
        timestamp
    )                                                    AS days_since_last_txn,
    is_fraud
FROM transactions;
-- PostgreSQL has no DATEDIFF function -- use:
--   (timestamp::date - LAG(timestamp) OVER (PARTITION BY customer_id ORDER BY timestamp)::date)
-- MySQL: DATEDIFF(timestamp, LAG(timestamp) OVER (...)) -- argument order matches above
-- SQL Server: DATEDIFF(day, LAG(timestamp) OVER (...), timestamp) -- as written above


/* ============================================================================
   SECTION 7: CUSTOMER-LEVEL RISK TIERING
   ----------------------------------------------------------------------------
   This is the actual segmentation deliverable: rolls transaction-level
   signals up to one row per customer and assigns a risk tier based on
   real historical behavior, not guesswork. Thresholds below (14 days,
   180 days, $500, 2 device changes) are illustrative starting points --
   replace with values justified by the lift analysis in Section 3.
   ============================================================================ */

SELECT
    customer_id,
    MAX(account_age_days)                                AS account_age_days,
    COUNT(*)                                             AS total_txns,
    COUNT(DISTINCT device_id)                             AS distinct_devices_used,
    SUM(CASE WHEN is_new_device THEN 1 ELSE 0 END)        AS new_device_events,
    ROUND(AVG(transaction_amount), 2)                     AS avg_txn_amount,
    MAX(transaction_amount)                               AS max_txn_amount,
    SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END)             AS fraud_events,
    CASE
        WHEN MAX(account_age_days) < 30 AND MAX(transaction_amount) > 500
            THEN 'high_risk_new_account'
        WHEN MAX(account_age_days) >= 180 AND COUNT(DISTINCT device_id) <= 2
            THEN 'low_risk_established'
        WHEN SUM(CASE WHEN is_new_device THEN 1 ELSE 0 END) > 1
            THEN 'elevated_risk_device_churn'
        ELSE 'medium_risk'
    END                                                    AS risk_tier
FROM transactions
GROUP BY customer_id
ORDER BY risk_tier, account_age_days;

-- Sanity check: confirm tier sizes and actual fraud rates per tier before
-- presenting this as a recommendation -- a tier should both (a) contain a
-- meaningful number of customers and (b) show a materially different
-- fraud rate from the others, or it isn't earning its place as a
-- separate tier.
/*
SELECT risk_tier, COUNT(*) AS customers_in_tier,
       SUM(fraud_events) AS total_fraud_events,
       ROUND(100.0 * SUM(fraud_events) / SUM(total_txns), 2) AS tier_fraud_rate_pct
FROM ( ...above query as a CTE... ) tiered
GROUP BY risk_tier;
*/


/* ============================================================================
   SECTION 8: COMPOSITE RISK SCORE
   ----------------------------------------------------------------------------
   A simple, explainable weighted score per transaction -- the kind of
   output that feeds a Tableau dashboard or a business rule ("add
   verification above score 50"). Weights below are illustrative; derive
   real weights from the lift values in Section 3 rather than guessing,
   so the score is evidence-based rather than arbitrary.
   ============================================================================ */

SELECT
    transaction_id,
    customer_id,
    (
        CASE WHEN is_new_device THEN 25 ELSE 0 END +
        CASE WHEN is_new_location THEN 20 ELSE 0 END +
        CASE WHEN failed_login_attempts >= 2 THEN 15 ELSE 0 END +
        CASE WHEN account_age_days < 14 THEN 20 ELSE 0 END +
        CASE WHEN shipping_billing_mismatch THEN 20 ELSE 0 END
    )                                                      AS composite_risk_score,
    is_fraud
FROM transactions
ORDER BY composite_risk_score DESC;


/* ============================================================================
   SECTION 9: VALIDATION -- does the score actually work?
   ----------------------------------------------------------------------------
   Before pitching the composite score, confirm fraud rate actually rises
   with score band. If it doesn't rise monotonically, the weights in
   Section 8 need rework.
   ============================================================================ */

WITH scored AS (
    SELECT
        transaction_id,
        is_fraud,
        (
            CASE WHEN is_new_device THEN 25 ELSE 0 END +
            CASE WHEN is_new_location THEN 20 ELSE 0 END +
            CASE WHEN failed_login_attempts >= 2 THEN 15 ELSE 0 END +
            CASE WHEN account_age_days < 14 THEN 20 ELSE 0 END +
            CASE WHEN shipping_billing_mismatch THEN 20 ELSE 0 END
        ) AS composite_risk_score
    FROM transactions
)
SELECT
    CASE
        WHEN composite_risk_score = 0  THEN '0 (no signals)'
        WHEN composite_risk_score < 30 THEN '1-29 (low)'
        WHEN composite_risk_score < 60 THEN '30-59 (medium)'
        ELSE '60+ (high)'
    END                                                  AS score_band,
    COUNT(*)                                             AS total_txns,
    SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END)             AS fraud_count,
    ROUND(100.0 * SUM(CASE WHEN is_fraud THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct
FROM scored
GROUP BY
    CASE
        WHEN composite_risk_score = 0  THEN '0 (no signals)'
        WHEN composite_risk_score < 30 THEN '1-29 (low)'
        WHEN composite_risk_score < 60 THEN '30-59 (medium)'
        ELSE '60+ (high)'
    END
ORDER BY MIN(composite_risk_score);


/* ============================================================================
   END OF SCRIPT

   Suggested next steps after running this:
     1. Use Section 3 (lift) output to set real, justified weights in
        Section 8, replacing the illustrative ones.
     2. Export Section 4, 7, and 9 result sets into Tableau/Excel to build
        the friction-vs-fraud-caught tradeoff visual for stakeholders.
     3. Remember: this is rule-based, explainable risk scoring for a
        strategy pitch -- not a predictive model. Flag that distinction
        clearly if presenting to a technical audience.
   ============================================================================ */