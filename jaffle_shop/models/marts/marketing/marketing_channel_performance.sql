with customers as (

    select * from {{ ref('customers') }}

),

orders as (

    select * from {{ ref('orders') }}

),

spend as (

    select * from {{ ref('stg_marketing_spend') }}

),

-- A new customer is a customer who places a first order. The month of the first order counts.
new_customers as (

    select
        cast({{ dbt.date_trunc('month', 'orders.order_date') }} as date) as performance_month,
        customers.acquisition_channel,
        count(*) as new_customers,
        sum(orders.net_item_amount) as first_order_net_sales

    from orders

    inner join customers
        on orders.customer_id = customers.customer_id

    where orders.is_first_order

    group by 1, 2

),

joined as (

    select
        coalesce(new_customers.performance_month, spend.spend_month) as performance_month,
        coalesce(new_customers.acquisition_channel, spend.acquisition_channel) as acquisition_channel,
        spend.spend_amount,
        coalesce(new_customers.new_customers, 0) as new_customers,
        coalesce(new_customers.first_order_net_sales, 0) as first_order_net_sales

    from new_customers

    full outer join spend
        on new_customers.performance_month = spend.spend_month
        and new_customers.acquisition_channel = spend.acquisition_channel

),

final as (

    select
        performance_month,
        acquisition_channel,
        case
            when acquisition_channel in ('organic_search', 'direct') then 'unpaid'
            else 'paid'
        end as channel_type,
        spend_amount,
        new_customers,
        cast(first_order_net_sales / (1 + {{ var('gst_rate') }}) as decimal(12, 2)) as first_order_revenue,
        cast(spend_amount / nullif(new_customers, 0) as decimal(12, 2)) as customer_acquisition_cost,
        round(first_order_net_sales / (1 + {{ var('gst_rate') }}) / nullif(spend_amount, 0), 2) as first_order_roas

    from joined

)

select * from final
