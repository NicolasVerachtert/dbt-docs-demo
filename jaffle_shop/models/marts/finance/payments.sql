with payments as (

    select * from {{ ref('stg_payments') }}

),

payment_methods as (

    select * from {{ ref('payment_methods') }}

),

orders as (

    select * from {{ ref('stg_orders') }}

),

final as (

    select
        payments.payment_id,
        payments.order_id,
        orders.customer_id,
        payments.created_at,
        payments.payment_date,
        payments.payment_method,
        payment_methods.payment_method_name,
        payments.payment_status,
        payments.amount,
        payment_methods.processing_fee_pct,
        case
            when payments.payment_status = 'success'
                then cast(payments.amount * payment_methods.processing_fee_pct / 100 as decimal(12, 2))
            else 0
        end as payment_fee_amount,
        payment_methods.is_new_cash

    from payments

    left join payment_methods
        on payments.payment_method = payment_methods.payment_method

    left join orders
        on payments.order_id = orders.order_id

)

select * from final
