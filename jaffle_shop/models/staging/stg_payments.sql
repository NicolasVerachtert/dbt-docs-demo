with source as (

    select * from {{ ref('raw_payments') }}

),

renamed as (

    select
        id as payment_id,
        order_id,
        payment_method,
        status as payment_status,
        -- `amount` is stored in cents, so we convert it to dollars
        {{ cents_to_dollars('amount') }} as amount,
        created_at,
        cast(created_at as date) as payment_date

    from source

)

select * from renamed
