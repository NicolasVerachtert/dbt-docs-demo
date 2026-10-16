with orders as (

    select * from {{ ref('orders') }}

),

customers as (

    select * from {{ ref('customers') }}

    where first_order_date is not null

),

customer_activity as (

    select distinct
        orders.customer_id,
        cast({{ dbt.date_trunc('month', 'customers.first_order_date') }} as date) as cohort_month,
        cast({{ dbt.date_trunc('month', 'orders.order_date') }} as date) as order_month

    from orders

    inner join customers
        on orders.customer_id = customers.customer_id

),

cohort_sizes as (

    select
        cohort_month,
        count(distinct customer_id) as cohort_size

    from customer_activity

    group by cohort_month

),

cohort_activity as (

    select
        cohort_month,
        {{ dbt.datediff('cohort_month', 'order_month', 'month') }} as months_since_first_order,
        count(distinct customer_id) as active_customers

    from customer_activity

    group by 1, 2

),

final as (

    select
        cohort_activity.cohort_month,
        cohort_activity.months_since_first_order,
        cohort_sizes.cohort_size,
        cohort_activity.active_customers,
        round(cohort_activity.active_customers / cohort_sizes.cohort_size, 4) as retention_rate

    from cohort_activity

    inner join cohort_sizes
        on cohort_activity.cohort_month = cohort_sizes.cohort_month

)

select * from final
