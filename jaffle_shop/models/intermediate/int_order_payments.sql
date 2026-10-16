{%- set payment_methods = var('payment_methods') -%}

with payments as (

    select * from {{ ref('stg_payments') }}

),

payment_methods as (

    select * from {{ ref('payment_methods') }}

),

payments_with_fees as (

    select
        payments.order_id,
        payments.payment_method,
        payments.payment_status,
        payments.amount,
        payment_methods.processing_fee_pct

    from payments

    left join payment_methods
        on payments.payment_method = payment_methods.payment_method

),

final as (

    select
        order_id,

        {% for payment_method in payment_methods -%}
        sum(case when payment_status = 'success' and payment_method = '{{ payment_method }}' then amount else 0 end) as {{ payment_method }}_amount,
        {% endfor -%}

        sum(case when payment_status = 'success' then amount else 0 end) as amount_paid,
        cast(sum(case when payment_status = 'success' then amount * processing_fee_pct / 100 else 0 end) as decimal(12, 2)) as payment_fee_amount,
        count(case when payment_status = 'success' then 1 end) as successful_payment_count,
        count(case when payment_status = 'failed' then 1 end) as failed_payment_count

    from payments_with_fees

    group by order_id

)

select * from final
