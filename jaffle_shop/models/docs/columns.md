{#- Shared column definitions. Use them with {{ doc("name") }} in the YAML files. -#}

{# ── Identifiers ─────────────────────────────────────────────────────────── #}

{% docs customer_id %}
Identifier of the customer. The web shop gives this number when the customer creates an account. The number does not change.
{% enddocs %}

{% docs order_id %}
Identifier of the order. The web shop gives this number when the customer places the order.
{% enddocs %}

{% docs order_item_id %}
Identifier of the order line. An order has one line for each product.
{% enddocs %}

{% docs product_id %}
Identifier of the product in the web shop.
{% enddocs %}

{% docs payment_id %}
Identifier of the payment attempt at the payment service provider (PSP).
{% enddocs %}

{% docs sku %}
Stock keeping unit (SKU). The warehouse uses this code. The first three letters show the category: `KIT` (kitchenware), `PAN` (pantry), `COF` (coffee and tea), `MER` (merchandise), `GFT` (gift cards).
{% enddocs %}

{# ── Order attributes ────────────────────────────────────────────────────── #}

{% docs order_date %}
Date (AEST) when the customer placed the order.
{% enddocs %}

{% docs order_status %}
Status of the order. The web shop changes the status during the life of the order.

| Status | Meaning |
|---|---|
| `placed` | The customer placed the order. The warehouse did not send it yet. |
| `shipped` | The warehouse sent the order. The order is in transit. |
| `completed` | The customer received the order. |
| `return_pending` | The customer asked for a return. The warehouse did not receive the goods yet. |
| `returned` | The warehouse received the returned goods. The customer got a refund. |

Only kitchenware and merchandise can be returned.
{% enddocs %}

{% docs sales_channel %}
Channel where the customer placed the order.

| Value | Meaning |
|---|---|
| `web` | The web shop in a browser. |
| `app` | The mobile app. |
{% enddocs %}

{% docs coupon_code %}
Coupon code that the customer used. NULL if the customer did not use a coupon.

| Code | Discount | Conditions |
|---|---|---|
| `WELCOME10` | 10% | First order only. |
| `WINTER15` | 15% | June to August. |
| `BLACKFRIDAY20` | 20% | Last week of November. |

Coupons do not apply to gift cards. Finance must approve each new coupon code.
{% enddocs %}

{% docs customer_order_number %}
Sequence number of the order for the customer. The first order of a customer has number 1.
{% enddocs %}

{% docs is_first_order %}
True if this order is the first order of the customer.
{% enddocs %}

{# ── Product attributes ──────────────────────────────────────────────────── #}

{% docs product_category %}
Category of the product.

| Category | Contents | Can be returned |
|---|---|---|
| `kitchenware` | Jaffle irons, jaffle makers and tools | Yes |
| `pantry` | Bread, fillings and sauces | No |
| `coffee_and_tea` | Coffee beans, tea and hot chocolate | No |
| `merchandise` | Aprons, mugs, bags and clothing | Yes |
| `gift_cards` | Gift cards of AUD 50 and AUD 100 | No |
{% enddocs %}

{% docs is_gift_card %}
True if the product is a gift card. A gift card sale is not revenue. Finance records the revenue when the customer uses the gift card.
{% enddocs %}

{% docs is_returnable %}
True if the customer can return the product. Only kitchenware and merchandise can be returned. Food, drinks and gift cards cannot be returned.
{% enddocs %}

{% docs list_price %}
Current price of one unit on the web shop, in AUD. Includes GST. The price on an order can be different. Refer to `unit_price`.
{% enddocs %}

{% docs unit_price %}
Price of one unit on the order date, in AUD. Includes GST.
{% enddocs %}

{% docs unit_cost %}
Current purchase cost of one unit, in AUD. Excludes GST. Purchasing updates this value when a supplier changes the price.
{% enddocs %}

{# ── Amounts ─────────────────────────────────────────────────────────────── #}

{% docs gross_amount %}
Gross sales: quantity multiplied by the unit price, in AUD. Before discounts. Includes GST.
{% enddocs %}

{% docs discount_amount %}
Coupon discount, in AUD. Includes GST.
{% enddocs %}

{% docs net_amount %}
Net sales: gross sales minus the discount, in AUD. Includes GST. Excludes the shipping fee.
{% enddocs %}

{% docs net_amount_excl_gst %}
Net sales without GST, in AUD. The calculation is: net sales / 1.1. Gift cards have no GST.

**Known limitation:** some food products are free of GST in Australia. This model uses 10% GST for all products, except gift cards.
{% enddocs %}

{% docs cost_amount %}
Cost of goods sold: quantity multiplied by the current unit cost, in AUD. Excludes GST.

**Known limitation:** the model uses the current unit cost, not the cost on the order date.
{% enddocs %}

{% docs gross_margin %}
Gross margin: net sales without GST minus the cost of goods sold, in AUD. Excludes gift cards and refunds.
{% enddocs %}

{% docs shipping_amount %}
Shipping fee of the order, in AUD. Includes GST. The fee is AUD 9.95. Shipping is free if net sales are AUD 100 or more, or if the order contains only gift cards.
{% enddocs %}

{% docs order_total %}
Order total: net sales plus the shipping fee, in AUD. Includes GST. The customer pays this amount.
{% enddocs %}

{% docs payment_method_amount %}
Amount of the order that the customer paid with this payment method, in AUD. Only successful payments. Zero if the customer did not use this method.
{% enddocs %}

{% docs amount_paid %}
Total of all successful payments for the order, in AUD. Failed payment attempts are not included.
{% enddocs %}

{% docs payment_fee_amount %}
Fee that the payment service provider charges, in AUD. The fee is a percentage of the payment. The seed `payment_methods` gives the percentage for each payment method.
{% enddocs %}

{% docs refund_amount %}
Total of all refunds for the order, in AUD. Includes GST. A refund can be for a part of the order.
{% enddocs %}

{% docs net_order_value %}
Net order value: order total minus refunds, in AUD. Includes GST.
{% enddocs %}

{# ── Payments ────────────────────────────────────────────────────────────── #}

{% docs payment_method %}
Payment method code.

| Code | Name |
|---|---|
| `credit_card` | Credit card |
| `debit_card` | Debit card |
| `digital_wallet` | Digital wallet |
| `buy_now_pay_later` | Buy now pay later |
| `gift_card` | Gift card |

To add a payment method, update the seed `payment_methods` and the project variable `payment_methods`.
{% enddocs %}

{% docs payment_attempt_status %}
Result of the payment attempt.

| Value | Meaning |
|---|---|
| `success` | The payment service provider accepted the payment. |
| `failed` | The payment service provider declined the payment. No money moved. |
{% enddocs %}

{% docs order_payment_status %}
Comparison of the amount paid with the order total.

| Value | Meaning |
|---|---|
| `paid` | The amount paid is equal to the order total. |
| `partially_paid` | The amount paid is less than the order total. |
| `overpaid` | The amount paid is more than the order total. |
| `unpaid` | There is no successful payment. |

All orders must have the status `paid`. A test checks this.
{% enddocs %}

{% docs is_new_cash %}
True if the payment method brings new money to the company. False for gift cards: the company received the money when the customer bought the gift card.
{% enddocs %}

{% docs refund_reason %}
Reason for the refund. Customer service selects the reason.

| Value | Meaning |
|---|---|
| `changed_mind` | The customer does not want the product. |
| `damaged_item` | The product arrived damaged. |
| `wrong_item` | The warehouse sent the wrong product. |
| `late_delivery` | The delivery was late. Customer service gave a refund as compensation. |
{% enddocs %}

{# ── Customers ───────────────────────────────────────────────────────────── #}

{% docs acquisition_channel %}
Marketing channel that brought the customer to the web shop. The web shop records the channel when the customer creates an account.

| Value | Meaning | Paid |
|---|---|---|
| `organic_search` | Search engine results, not ads. | No |
| `paid_search` | Search engine ads. | Yes |
| `paid_social` | Social media ads. | Yes |
| `affiliate` | Partner websites. Jaffle Shop pays a commission. | Yes |
| `referral` | A link from an existing customer. Both customers get a credit. | Yes |
| `direct` | The customer typed the web address. | No |
{% enddocs %}

{% docs state_code %}
Official abbreviation of the state or territory of the delivery address, for example `NSW`. NULL if the state is not known.
{% enddocs %}

{% docs sales_region %}
Sales region of the state. The sales team uses these regions for targets.

| Region | States |
|---|---|
| East | ACT, NSW |
| North | NT, QLD |
| South | SA, TAS, VIC |
| West | WA |
{% enddocs %}

{% docs is_marketing_opt_in %}
True if the customer agrees to receive marketing email. The customer can change this setting in the account at any time. Do not send marketing email if this value is false.
{% enddocs %}

{% docs signup_date %}
Date (AEST) when the customer created the account.
{% enddocs %}

{% docs lifetime_value %}
Lifetime value (LTV): the total net order value of the customer since the first order, in AUD. Includes GST. Zero if the customer has no orders.
{% enddocs %}

{% docs average_order_value %}
Average order value (AOV): the mean order total of the customer, in AUD. Includes GST. NULL if the customer has no orders.
{% enddocs %}

{% docs days_since_last_order %}
Number of days between the most recent order of the customer and the as-of date. The as-of date is the date of the most recent order in the data. NULL if the customer has no orders.
{% enddocs %}

{% docs customer_status %}
Status of the customer on the as-of date.

| Value | Meaning |
|---|---|
| `prospect` | The customer has an account but no orders. |
| `active` | The most recent order is 180 days old or less. |
| `lapsed` | The most recent order is more than 180 days old. |
{% enddocs %}

{# ── Segments ────────────────────────────────────────────────────────────── #}

{% docs recency_score %}
Recency score from 1 to 5. A high score means a recent order.

| Days since last order | Score |
|---|---|
| 0 to 30 | 5 |
| 31 to 90 | 4 |
| 91 to 180 | 3 |
| 181 to 365 | 2 |
| More than 365 | 1 |
{% enddocs %}

{% docs frequency_score %}
Frequency score from 1 to 5. A high score means many orders.

| Number of orders | Score |
|---|---|
| 6 or more | 5 |
| 4 or 5 | 4 |
| 3 | 3 |
| 2 | 2 |
| 1 | 1 |
{% enddocs %}

{% docs monetary_score %}
Monetary score from 1 to 5. The score is the quintile of the lifetime value. The 20% of customers with the highest lifetime value get score 5.
{% enddocs %}

{% docs rfm_segment %}
Customer segment. The segment comes from the recency score (R) and the frequency score (F). The first rule that matches gives the segment.

| Order | Segment | Rule | Meaning |
|---|---|---|---|
| 1 | `champions` | R ≥ 4 and F ≥ 4 | Recent and frequent customers. |
| 2 | `loyal` | R ≥ 3 and F ≥ 3 | Frequent customers who ordered in the last 180 days. |
| 3 | `new_customers` | R ≥ 4 and F = 1 | One recent order. |
| 4 | `at_risk` | R ≤ 2 and F ≥ 3 | Frequent customers who did not order in the last 180 days. |
| 5 | `lost` | R = 1 | No order for more than a year. |
| 6 | `hibernating` | R = 2 | No order for 6 to 12 months. |
| 7 | `needs_attention` | All other customers | |
{% enddocs %}

{# ── Rates ───────────────────────────────────────────────────────────────── #}

{% docs retention_rate %}
Retention rate: active customers divided by the cohort size. A value of 0.25 means that 25% of the cohort ordered in that month.
{% enddocs %}

{% docs customer_acquisition_cost %}
Customer acquisition cost (CAC): marketing spend divided by the number of new customers, in AUD. Excludes GST. NULL for unpaid channels and for months without new customers.
{% enddocs %}

{% docs first_order_roas %}
First-order return on ad spend (ROAS): first-order revenue divided by the marketing spend. A value of 1.5 means AUD 1.50 of revenue for each AUD 1 of spend. NULL for unpaid channels.

This value shows only the first order. The lifetime value of the new customers is higher.
{% enddocs %}
