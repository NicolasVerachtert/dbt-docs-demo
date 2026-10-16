with scores as (

    select * from {{ ref('customer_rfm_scores') }}

),

segmented as (

    select
        customer_id,
        recency_days,
        frequency,
        monetary_value,
        recency_score,
        frequency_score,
        monetary_score,
        cast(recency_score as varchar)
            || cast(frequency_score as varchar)
            || cast(monetary_score as varchar) as rfm_code,

        -- The order of the rules is important. The first rule that matches gives the segment.
        case
            when recency_score >= 4 and frequency_score >= 4 then 'champions'
            when recency_score >= 3 and frequency_score >= 3 then 'loyal'
            when recency_score >= 4 and frequency_score = 1 then 'new_customers'
            when recency_score <= 2 and frequency_score >= 3 then 'at_risk'
            when recency_score = 1 then 'lost'
            when recency_score = 2 then 'hibernating'
            else 'needs_attention'
        end as rfm_segment

    from scores

)

select * from segmented
