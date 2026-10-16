with order_items as (

    select * from {{ ref('order_items') }}

),

orders as (

    select * from {{ ref('orders') }}

),

refunds as (

    select * from {{ ref('stg_refunds') }}

),

payments as (

    select * from {{ ref('payments') }}

),

-- Revenue is recorded in the month of the order.
sales as (

    select
        cast({{ dbt.date_trunc('month', 'order_date') }} as date) as revenue_month,
        sum(case when not is_gift_card then gross_amount else 0 end) as gross_sales,
        sum(case when not is_gift_card then discount_amount else 0 end) as discount_amount,
        sum(case when not is_gift_card then net_amount else 0 end) as net_sales,
        sum(case when is_gift_card then net_amount else 0 end) as gift_card_sales,
        sum(case when not is_gift_card then cost_amount else 0 end) as cost_of_goods_sold,
        sum(case when not is_gift_card then gross_margin else 0 end) as gross_margin

    from order_items

    group by 1

),

order_counts as (

    select
        cast({{ dbt.date_trunc('month', 'order_date') }} as date) as revenue_month,
        count(*) as order_count,
        count(case when is_first_order then 1 end) as first_order_count,
        sum(shipping_amount) as shipping_revenue

    from orders

    group by 1

),

-- Refunds are recorded in the month of the refund, not in the month of the order.
refund_totals as (

    select
        cast({{ dbt.date_trunc('month', 'refund_date') }} as date) as revenue_month,
        sum(refund_amount) as refund_amount

    from refunds

    group by 1

),

fee_totals as (

    select
        cast({{ dbt.date_trunc('month', 'payment_date') }} as date) as revenue_month,
        sum(payment_fee_amount) as payment_fee_amount

    from payments

    group by 1

),

months as (

    select revenue_month from sales
    union
    select revenue_month from refund_totals
    union
    select revenue_month from fee_totals

),

joined as (

    select
        months.revenue_month,
        coalesce(order_counts.order_count, 0) as order_count,
        coalesce(order_counts.first_order_count, 0) as first_order_count,
        coalesce(sales.gross_sales, 0) as gross_sales,
        coalesce(sales.discount_amount, 0) as discount_amount,
        coalesce(sales.net_sales, 0) as net_sales,
        coalesce(order_counts.shipping_revenue, 0) as shipping_revenue,
        coalesce(refund_totals.refund_amount, 0) as refund_amount,
        coalesce(sales.gift_card_sales, 0) as gift_card_sales,
        coalesce(sales.cost_of_goods_sold, 0) as cost_of_goods_sold,
        coalesce(sales.gross_margin, 0) as gross_margin,
        coalesce(fee_totals.payment_fee_amount, 0) as payment_fee_amount

    from months

    left join sales
        on months.revenue_month = sales.revenue_month

    left join order_counts
        on months.revenue_month = order_counts.revenue_month

    left join refund_totals
        on months.revenue_month = refund_totals.revenue_month

    left join fee_totals
        on months.revenue_month = fee_totals.revenue_month

),

final as (

    select
        revenue_month,
        order_count,
        first_order_count,
        gross_sales,
        discount_amount,
        net_sales,
        shipping_revenue,
        refund_amount,
        net_sales + shipping_revenue - refund_amount as net_revenue_incl_gst,
        cast((net_sales + shipping_revenue - refund_amount) / (1 + {{ var('gst_rate') }}) as decimal(12, 2)) as net_revenue,
        cost_of_goods_sold,
        gross_margin,
        round(gross_margin / nullif(net_sales / (1 + {{ var('gst_rate') }}), 0), 4) as gross_margin_pct,
        payment_fee_amount,
        gift_card_sales

    from joined

)

select * from final
