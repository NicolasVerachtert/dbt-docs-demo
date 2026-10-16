with source as (

    select * from {{ ref('raw_order_items') }}

),

renamed as (

    select
        id as order_item_id,
        order_id,
        product_id,
        quantity,
        {{ cents_to_dollars('unit_price') }} as unit_price,
        {{ cents_to_dollars('discount_amount') }} as discount_amount

    from source

)

select * from renamed
