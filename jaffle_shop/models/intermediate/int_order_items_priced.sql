with order_items as (

    select * from {{ ref('stg_order_items') }}

),

products as (

    select * from {{ ref('stg_products') }}

),

joined as (

    select
        order_items.order_item_id,
        order_items.order_id,
        order_items.product_id,
        products.product_category,
        products.product_category = 'gift_cards' as is_gift_card,
        order_items.quantity,
        order_items.unit_price,
        order_items.quantity * order_items.unit_price as gross_amount,
        order_items.discount_amount,
        order_items.quantity * order_items.unit_price - order_items.discount_amount as net_amount,
        products.unit_cost,
        order_items.quantity * products.unit_cost as cost_amount

    from order_items

    left join products
        on order_items.product_id = products.product_id

),

final as (

    select
        order_item_id,
        order_id,
        product_id,
        product_category,
        is_gift_card,
        quantity,
        unit_price,
        gross_amount,
        discount_amount,
        net_amount,
        -- Gift cards have no GST when the customer buys them. GST applies when the customer uses the card.
        case
            when is_gift_card then net_amount
            else cast(net_amount / (1 + {{ var('gst_rate') }}) as decimal(12, 2))
        end as net_amount_excl_gst,
        cost_amount

    from joined

)

select * from final
