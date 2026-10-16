with source as (

    select * from {{ ref('raw_orders') }}

),

renamed as (

    select
        id as order_id,
        user_id as customer_id,
        order_date,
        status,
        sales_channel,
        upper(trim(coupon_code)) as coupon_code,
        {{ cents_to_dollars('shipping_fee') }} as shipping_amount

    from source

)

select * from renamed
