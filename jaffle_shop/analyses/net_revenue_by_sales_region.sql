-- Net order value and number of customers for each sales region and year.
-- Run `dbt compile` and copy the SQL from target/compiled to run it.

with orders as (

    select * from {{ ref('orders') }}

),

customers as (

    select * from {{ ref('customers') }}

)

select
    coalesce(customers.sales_region, 'Unknown') as sales_region,
    extract(year from orders.order_date) as order_year,
    count(distinct orders.customer_id) as customer_count,
    sum(orders.net_order_value) as net_order_value

from orders

left join customers
    on orders.customer_id = customers.customer_id

group by 1, 2

order by 1, 2
