with source as (

    select * from {{ ref('raw_products') }}

),

renamed as (

    select
        id as product_id,
        sku,
        name as product_name,
        category as product_category,
        {{ cents_to_dollars('price') }} as list_price,
        {{ cents_to_dollars('cost') }} as unit_cost,
        -- Only kitchenware and merchandise can be returned. Food, drinks and gift cards cannot be returned.
        category in ('kitchenware', 'merchandise') as is_returnable,
        is_active,
        launched_on

    from source

)

select * from renamed
