with customers as (

    select * from {{ ref('customers') }}

    where number_of_orders > 0

),

scored as (

    select
        customer_id,
        days_since_last_order as recency_days,
        number_of_orders as frequency,
        lifetime_value as monetary_value,

        case
            when days_since_last_order <= 30 then 5
            when days_since_last_order <= 90 then 4
            when days_since_last_order <= 180 then 3
            when days_since_last_order <= 365 then 2
            else 1
        end as recency_score,

        case
            when number_of_orders >= 6 then 5
            when number_of_orders >= 4 then 4
            when number_of_orders = 3 then 3
            when number_of_orders = 2 then 2
            else 1
        end as frequency_score,

        -- Quintiles: the 20% of customers with the highest lifetime value get score 5.
        ntile(5) over (order by lifetime_value, customer_id) as monetary_score

    from customers

)

select * from scored
