with refunds as (

    select * from {{ ref('stg_refunds') }}

),

final as (

    select
        order_id,
        sum(refund_amount) as refund_amount,
        count(*) as refund_count,
        min(refund_date) as first_refund_date

    from refunds

    group by order_id

)

select * from final
