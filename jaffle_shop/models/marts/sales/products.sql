with products as (

    select * from {{ ref('stg_products') }}

),

order_items as (

    select * from {{ ref('order_items') }}

),

product_sales as (

    select
        product_id,
        count(distinct order_id) as order_count,
        sum(quantity) as units_sold,
        sum(case when order_status = 'returned' and is_returnable then quantity else 0 end) as units_returned,
        sum(net_amount) as net_sales,
        sum(gross_margin) as gross_margin,
        max(order_date) as last_sold_on

    from order_items

    group by product_id

),

final as (

    select
        products.product_id,
        products.sku,
        products.product_name,
        products.product_category,
        products.list_price,
        products.unit_cost,
        case
            when products.product_category = 'gift_cards' then null
            else round(
                (products.list_price / (1 + {{ var('gst_rate') }}) - products.unit_cost)
                / (products.list_price / (1 + {{ var('gst_rate') }})),
                4
            )
        end as list_margin_pct,
        products.is_returnable,
        products.is_active,
        products.launched_on,
        cast(coalesce(product_sales.order_count, 0) as integer) as order_count,
        cast(coalesce(product_sales.units_sold, 0) as integer) as units_sold,
        cast(coalesce(product_sales.units_returned, 0) as integer) as units_returned,
        case
            when products.is_returnable
                then round(product_sales.units_returned / nullif(product_sales.units_sold, 0), 4)
        end as return_rate,
        coalesce(product_sales.net_sales, 0) as net_sales,
        coalesce(product_sales.gross_margin, 0) as gross_margin,
        product_sales.last_sold_on

    from products

    left join product_sales
        on products.product_id = product_sales.product_id

)

select * from final
