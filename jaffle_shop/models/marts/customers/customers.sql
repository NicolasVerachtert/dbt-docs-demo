with customers as (

    select * from {{ ref('stg_customers') }}

),

states as (

    select * from {{ ref('au_states') }}

),

orders as (

    select * from {{ ref('orders') }}

),

-- The as-of date is the date of the most recent order in the data.
as_of as (

    select max(order_date) as as_of_date from orders

),

customer_orders as (

    select
        customer_id,
        min(order_date) as first_order_date,
        max(order_date) as most_recent_order_date,
        count(order_id) as number_of_orders,
        sum(order_total) as total_order_amount,
        sum(net_order_value) as lifetime_value

    from orders

    group by customer_id

),

joined as (

    select
        customers.customer_id,
        customers.first_name,
        customers.last_name,
        customers.email,
        customers.phone,
        customers.city,
        customers.state_code,
        states.state_name,
        states.sales_region,
        customers.postcode,
        customers.acquisition_channel,
        customers.is_marketing_opt_in,
        customers.signup_date,
        customer_orders.first_order_date,
        customer_orders.most_recent_order_date,
        coalesce(customer_orders.number_of_orders, 0) as number_of_orders,
        coalesce(customer_orders.lifetime_value, 0) as lifetime_value,
        customer_orders.total_order_amount / customer_orders.number_of_orders as average_order_value,
        {{ dbt.datediff('customer_orders.most_recent_order_date', 'as_of.as_of_date', 'day') }} as days_since_last_order

    from customers

    cross join as_of

    left join states
        on customers.state_code = states.state_code

    left join customer_orders
        on customers.customer_id = customer_orders.customer_id

),

final as (

    select
        cast(customer_id as integer) as customer_id,
        cast(first_name as varchar) as first_name,
        cast(last_name as varchar) as last_name,
        cast(email as varchar) as email,
        cast(phone as varchar) as phone,
        cast(city as varchar) as city,
        cast(state_code as varchar) as state_code,
        cast(state_name as varchar) as state_name,
        cast(sales_region as varchar) as sales_region,
        cast(postcode as varchar) as postcode,
        cast(acquisition_channel as varchar) as acquisition_channel,
        cast(is_marketing_opt_in as boolean) as is_marketing_opt_in,
        cast(signup_date as date) as signup_date,
        cast(first_order_date as date) as first_order_date,
        cast(most_recent_order_date as date) as most_recent_order_date,
        cast(number_of_orders as integer) as number_of_orders,
        cast(lifetime_value as decimal(12, 2)) as lifetime_value,
        cast(average_order_value as decimal(12, 2)) as average_order_value,
        cast(days_since_last_order as integer) as days_since_last_order,
        cast(
            case
                when number_of_orders = 0 then 'prospect'
                when days_since_last_order <= 180 then 'active'
                else 'lapsed'
            end as varchar
        ) as customer_status

    from joined

)

select * from final
