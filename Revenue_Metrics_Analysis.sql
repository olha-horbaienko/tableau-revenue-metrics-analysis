-- ============================================================
-- Final Project: Revenue Metrics Analysis 
-- Фінальний проєкт: Аналіз показників доходу
--
-- Student: Horbaienko Olha
-- Course: DA 35 (GoIT)
-- Date: 2026
-- Database: PostgreSQL
-- Tool: DBeaver
-- ============================================================


select*
from project.games_payments gp;


select*
from project.games_paid_users gp;



WITH monthly_revenue AS (

SELECT
    gp.user_id,
    DATE_TRUNC('month', gp.payment_date::date)::date AS payment_month,
    SUM(gp.revenue_amount_usd) AS revenue

FROM project.games_payments gp

GROUP BY
    gp.user_id,
    DATE_TRUNC('month', gp.payment_date::date)::date

),

revenue_lag_lead AS (

    SELECT

        mr.user_id,
        mr.payment_month,
        mr.revenue,

        (mr.payment_month - INTERVAL '1 month')::date AS previous_calendar_month,

        (mr.payment_month + INTERVAL '1 month')::date AS next_calendar_month,

        LAG(mr.payment_month) OVER (
            PARTITION BY mr.user_id
            ORDER BY mr.payment_month
        ) AS previous_paid_month,

        LEAD(mr.payment_month) OVER (
            PARTITION BY mr.user_id
            ORDER BY mr.payment_month
        ) AS next_paid_month,

        LAG(mr.revenue) OVER (
            PARTITION BY mr.user_id
            ORDER BY mr.payment_month
        ) AS previous_revenue,

        LEAD(mr.revenue) OVER (
            PARTITION BY mr.user_id
            ORDER BY mr.payment_month
        ) AS next_revenue

    FROM monthly_revenue mr

),

revenue_metrics AS (

    SELECT

        rll.user_id,
        rll.payment_month,
        rll.revenue,

        rll.previous_calendar_month,
        rll.next_calendar_month,
        rll.previous_paid_month,
        rll.next_paid_month,
        rll.previous_revenue,
        rll.next_revenue,

        -- New Paid User 
        CASE
            WHEN rll.previous_paid_month IS NULL
            THEN 1
        END AS new_paid_user,

        -- New MRR 
        CASE
            WHEN rll.previous_paid_month IS NULL
            THEN rll.revenue
        END AS new_mrr,

        -- Expansion Revenue 
        CASE
            WHEN rll.previous_paid_month = rll.previous_calendar_month
                 AND rll.revenue > rll.previous_revenue
            THEN rll.revenue - rll.previous_revenue
        END AS expansion_revenue,

        -- Contraction Revenue 
        CASE
            WHEN rll.previous_paid_month = rll.previous_calendar_month
                 AND rll.revenue < rll.previous_revenue
            THEN rll.revenue - rll.previous_revenue
        END AS contraction_revenue,

        -- Churned User
        CASE
            WHEN rll.next_paid_month IS NULL
                 OR rll.next_paid_month <> rll.next_calendar_month
            THEN 1
        END AS churned_user,

        -- Churned Revenue
        CASE
            WHEN rll.next_paid_month IS NULL
                 OR rll.next_paid_month <> rll.next_calendar_month
            THEN rll.revenue
        END AS churned_revenue,

        -- Churn Month 
        CASE
            WHEN rll.next_paid_month IS NULL
                 OR rll.next_paid_month <> rll.next_calendar_month
            THEN rll.next_calendar_month
        END AS churn_month,

        -- Back From Churn User
        CASE
            WHEN rll.previous_paid_month IS NOT NULL
                 AND rll.previous_paid_month <> rll.previous_calendar_month
            THEN 1
        END AS back_from_churn_user

    FROM revenue_lag_lead rll

)

SELECT

    rm.*,

    gpu.game_name,
    gpu.language,
    gpu.age,
    gpu.has_older_device_model

FROM revenue_metrics rm

LEFT JOIN project.games_paid_users gpu
    USING (user_id);









