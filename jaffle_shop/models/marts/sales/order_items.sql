with order_items as (

    select * from {{ ref('int_order_items_priced') }}

),

orders as (

    select * from {{ ref('stg_orders') }}

),

products as (

    select * from {{ ref('stg_products') }}

),

final as (

    select
        order_items.order_item_id,
        order_items.order_id,
        orders.customer_id,
        orders.order_date,
        orders.status as order_status,
        order_items.product_id,
        products.sku,
        products.product_name,
        order_items.product_category,
        order_items.is_gift_card,
        products.is_returnable,
        order_items.quantity,
        order_items.unit_price,
        order_items.gross_amount,
        order_items.discount_amount,
        order_items.net_amount,
        order_items.net_amount_excl_gst,
        order_items.cost_amount,
        order_items.net_amount_excl_gst - order_items.cost_amount as gross_margin

    from order_items

    inner join orders
        on order_items.order_id = orders.order_id

    left join products
        on order_items.product_id = products.product_id

)

select * from final
