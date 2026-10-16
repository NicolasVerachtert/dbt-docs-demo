{#- Descriptions of the mart models. Each description has the same sections. -#}

{% docs model_orders %}
One row for each order from the web shop and the mobile app.

**Use this table to**
- count orders by day, sales channel or status.
- find the order total, the amount paid and the refunds of an order.
- find the first order of a customer.

**Grain:** one row for each `order_id`.

**Business rules**
1. Order total = net sales + shipping fee.
2. Net order value = order total − refunds.
3. Only successful payments count in `amount_paid`. Failed payment attempts are in `payments`.
4. Each order must be fully paid. A test checks this.

**Contract:** this table has an enforced contract. The column names and data types do not change without a new version.
{% enddocs %}

{% docs model_order_items %}
One row for each product in an order (order line).

**Use this table to**
- analyse sales by product or by product category.
- calculate the gross margin of a product.

**Grain:** one row for each `order_item_id`.

**Business rules**
1. Gross sales = quantity × unit price.
2. Net sales = gross sales − discount.
3. Gross margin = net sales without GST − cost of goods sold.

**Known limitations**
- The cost of goods sold uses the current unit cost, not the cost on the order date.
- Some food products are free of GST. The model uses 10% GST for all products, except gift cards.
{% enddocs %}

{% docs model_products %}
One row for each product in the catalogue, with the sales since launch.

**Use this table to**
- find the best-selling products.
- compare the list margin of products.
- find products with a high return rate.

**Grain:** one row for each `product_id`. Includes products that are not for sale any more.

**Business rules**
1. List margin = (list price without GST − unit cost) / list price without GST.
2. Return rate = units returned / units sold. Only for products that can be returned.
3. Finance target: the list margin of each product is 30% or more. A test gives a warning if a product is below the target.
{% enddocs %}

{% docs model_customers %}
One row for each customer account, with the order history of the customer.

**Use this table to**
- count customers by state, sales region or acquisition channel.
- find the lifetime value and the average order value of a customer.
- find active and lapsed customers.

**Grain:** one row for each `customer_id`. Includes customers without orders (prospects).

**Business rules**
1. The as-of date is the date of the most recent order in the data.
2. An active customer has an order in the last 180 days.
3. Lifetime value = total net order value of all orders.

**Personal data:** this table contains names, email addresses, phone numbers and postcodes. Use it only with a business need. For marketing email, use `crm_audience`.

**Contract:** this table has an enforced contract. The column names and data types do not change without a new version.
{% enddocs %}

{% docs model_customer_rfm_scores %}
RFM scores for each customer with one or more orders.

This table is **private** to the Customer Insights team. The scoring method can change without a notice. Use `customer_segments` instead.

**Grain:** one row for each `customer_id` with one or more orders.
{% enddocs %}

{% docs model_customer_segments %}
Customer segment for each customer with one or more orders. The segment comes from the RFM method (recency, frequency and monetary value).

**Use this table to**
- select customers for a marketing campaign.
- monitor the number of loyal customers and the number of customers at risk.

**Grain:** one row for each `customer_id` with one or more orders. Prospects are not in this table.

**Business rules**
1. Each customer gets three scores from 1 to 5: recency (R), frequency (F) and monetary value (M).
2. The segment comes from the R score and the F score. Refer to the column `rfm_segment`.
3. The M score does not change the segment. Use it to sort the customers in a segment.

**Approved by:** Customer Insights Lead, 2026-03-12.
{% enddocs %}

{% docs model_customer_cohorts %}
Retention of customers by cohort. A cohort is the group of customers with the first order in the same month.

**Use this table to**
- see how many customers order again after their first order.
- compare the retention of different cohorts.

**Grain:** one row for each `cohort_month` and `months_since_first_order`. A month without orders from the cohort has no row.

**Business rules**
1. Month 0 is the month of the first order. The retention rate in month 0 is always 1.
2. An active customer has one or more orders in the month.
{% enddocs %}

{% docs model_payments %}
One row for each payment attempt at the payment service provider (PSP). Includes failed attempts.

**Use this table to**
- reconcile the PSP settlement file with the orders.
- calculate the payment fees by payment method.
- monitor the number of failed payments.

**Grain:** one row for each `payment_id`.

**Business rules**
1. Only successful payments move money.
2. The PSP charges a fee on successful payments only.
3. A gift card payment is not new cash. Refer to `is_new_cash`.
{% enddocs %}

{% docs model_monthly_revenue %}
Revenue, margin and costs for each month. Finance uses this table for the monthly management report.

**Use this table to**
- report net revenue and gross margin by month.
- compare months and years.

**Grain:** one row for each `revenue_month`.

**Business rules**
1. Revenue is recorded in the month of the order.
2. Refunds are recorded in the month of the refund, not in the month of the order.
3. Gift card sales are not revenue. They are in `gift_card_sales`. Finance records the revenue when the customer uses the gift card.
4. Net revenue = (net sales + shipping fees − refunds) without GST.
5. Payment fees are recorded in the month of the payment.

**Known limitations**
- The gross margin does not include refunds and payment fees.
- The current month is not complete until the first day of the next month.

**Approved by:** Financial Controller, 2026-01-20.
{% enddocs %}

{% docs model_marketing_channel_performance %}
Marketing spend, new customers and acquisition cost for each month and each acquisition channel.

**Use this table to**
- compare the customer acquisition cost (CAC) of the marketing channels.
- compare the first-order return on ad spend (ROAS) of the marketing channels.

**Grain:** one row for each `performance_month` and `acquisition_channel`.

**Business rules**
1. A new customer is a customer who places a first order. The month of the first order counts, not the month of the signup.
2. The channel of a customer is the channel of the signup.
3. Spend and revenue exclude GST.

**Known limitations**
- The marketing spend for the current month is available after the 5th working day of the next month. Before that date, the spend is NULL.
- The table does not show the cost of unpaid channels, for example search engine optimisation.
{% enddocs %}

{% docs model_crm_audience %}
Customers who agree to receive marketing email. The CRM tool gets this table every day at 07:00.

**Use this table to:** send data to the CRM tool only. Do not use it for reports.

**Grain:** one row for each `customer_id` with `is_marketing_opt_in = true`.

**Privacy rules**
1. Only customers who agree to receive marketing email are in this table. A test checks this.
2. The table contains only the data that the CRM tool needs. It does not contain the last name, the phone number or the postcode.
3. The table does not contain the exact lifetime value. It contains a band, for example `100-249`.
4. The legal basis is consent. The privacy officer approved this use on 2025-11-04.
{% enddocs %}
