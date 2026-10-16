-- The totals in `monthly_revenue` are equal to the totals in `orders`.
-- The monthly report and the order data must show the same sales and refunds.

with monthly as (

    select
        sum(net_sales + gift_card_sales) as net_item_amount,
        sum(shipping_revenue) as shipping_amount,
        sum(refund_amount) as refund_amount

    from {{ ref('monthly_revenue') }}

),

orders as (

    select
        sum(net_item_amount) as net_item_amount,
        sum(shipping_amount) as shipping_amount,
        sum(refund_amount) as refund_amount

    from {{ ref('orders') }}

)

select *

from monthly

cross join orders

where monthly.net_item_amount != orders.net_item_amount
    or monthly.shipping_amount != orders.shipping_amount
    or monthly.refund_amount != orders.refund_amount
