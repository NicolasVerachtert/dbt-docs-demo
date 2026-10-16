{%- set payment_methods = var('payment_methods') -%}

with orders as (

    select * from {{ ref('stg_orders') }}

),

order_items as (

    select * from {{ ref('int_order_items_priced') }}

),

order_payments as (

    select * from {{ ref('int_order_payments') }}

),

order_refunds as (

    select * from {{ ref('int_order_refunds') }}

),

order_item_totals as (

    select
        order_id,
        sum(quantity) as item_quantity,
        sum(gross_amount) as gross_item_amount,
        sum(discount_amount) as discount_amount,
        sum(net_amount) as net_item_amount

    from order_items

    group by order_id

),

joined as (

    select
        orders.order_id,
        orders.customer_id,
        orders.order_date,
        orders.status,
        orders.sales_channel,
        orders.coupon_code,
        row_number() over (
            partition by orders.customer_id
            order by orders.order_date, orders.order_id
        ) as customer_order_number,
        order_item_totals.item_quantity,
        order_item_totals.gross_item_amount,
        order_item_totals.discount_amount,
        order_item_totals.net_item_amount,
        orders.shipping_amount,
        order_item_totals.net_item_amount + orders.shipping_amount as order_total,

        {% for payment_method in payment_methods -%}
        coalesce(order_payments.{{ payment_method }}_amount, 0) as {{ payment_method }}_amount,
        {% endfor -%}

        coalesce(order_payments.amount_paid, 0) as amount_paid,
        coalesce(order_payments.payment_fee_amount, 0) as payment_fee_amount,
        coalesce(order_refunds.refund_amount, 0) as refund_amount

    from orders

    left join order_item_totals
        on orders.order_id = order_item_totals.order_id

    left join order_payments
        on orders.order_id = order_payments.order_id

    left join order_refunds
        on orders.order_id = order_refunds.order_id

),

final as (

    select
        cast(order_id as integer) as order_id,
        cast(customer_id as integer) as customer_id,
        cast(order_date as date) as order_date,
        cast(status as varchar) as status,
        cast(sales_channel as varchar) as sales_channel,
        cast(coupon_code as varchar) as coupon_code,
        cast(customer_order_number as integer) as customer_order_number,
        customer_order_number = 1 as is_first_order,
        cast(item_quantity as integer) as item_quantity,
        cast(gross_item_amount as decimal(12, 2)) as gross_item_amount,
        cast(discount_amount as decimal(12, 2)) as discount_amount,
        cast(net_item_amount as decimal(12, 2)) as net_item_amount,
        cast(shipping_amount as decimal(12, 2)) as shipping_amount,
        cast(order_total as decimal(12, 2)) as order_total,

        {% for payment_method in payment_methods -%}
        cast({{ payment_method }}_amount as decimal(12, 2)) as {{ payment_method }}_amount,
        {% endfor -%}

        cast(amount_paid as decimal(12, 2)) as amount_paid,
        cast(
            case
                when amount_paid = 0 then 'unpaid'
                when amount_paid < order_total then 'partially_paid'
                when amount_paid > order_total then 'overpaid'
                else 'paid'
            end as varchar
        ) as payment_status,
        cast(payment_fee_amount as decimal(12, 2)) as payment_fee_amount,
        cast(refund_amount as decimal(12, 2)) as refund_amount,
        cast(order_total - refund_amount as decimal(12, 2)) as net_order_value

    from joined

)

select * from final
