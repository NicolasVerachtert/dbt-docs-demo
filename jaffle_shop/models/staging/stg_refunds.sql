with source as (

    select * from {{ ref('raw_refunds') }}

),

renamed as (

    select
        id as refund_id,
        order_id,
        {{ cents_to_dollars('amount') }} as refund_amount,
        reason as refund_reason,
        refunded_at,
        cast(refunded_at as date) as refund_date

    from source

)

select * from renamed
