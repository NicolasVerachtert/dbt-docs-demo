-- The total of successful payments in `payments` is equal to the total amount paid in `orders`.
-- Finance uses both tables. A difference shows a problem in the joins.

with payment_total as (

    select sum(amount) as total from {{ ref('payments') }}
    where payment_status = 'success'

),

order_total as (

    select sum(amount_paid) as total from {{ ref('orders') }}

)

select
    payment_total.total as payment_total,
    order_total.total as order_total

from payment_total

cross join order_total

where payment_total.total != order_total.total
