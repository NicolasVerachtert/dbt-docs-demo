{% docs __overview__ %}

# Jaffle Shop data documentation

Jaffle Shop is a fictional company. It sells jaffle irons, food for jaffles, coffee, tea and merchandise. Customers order on the web shop and in the mobile app. Jaffle Shop delivers to customers in Australia.

This site documents the data on the Jaffle Shop data platform. Use this site to:

- find the correct table for a question.
- read the definition of a table or a column.
- find the owner of the data.
- see where the data comes from (lineage).
- see which data quality checks apply.

## Start here

| Question | Table |
|---|---|
| How many orders do we get? How much do customers spend? | `orders` |
| Which products sell? Which products come back? | `products`, `order_items` |
| Who are our customers? What is their lifetime value? | `customers` |
| Which customers are loyal? Which customers do we lose? | `customer_segments` |
| How many customers order again after their first order? | `customer_cohorts` |
| What is our revenue and margin each month? | `monthly_revenue` |
| What does a new customer cost for each marketing channel? | `marketing_channel_performance` |
| Which payments failed? What are the payment fees? | `payments` |

Use only the tables in the **marts** schema for reports. The other schemas can change without a notice.

## How to read this site

- Use the search bar to find a table or a column.
- Open a table to read its description, its columns and its tests.
- Open the lineage graph to see the tables before and after a table.
- **dbt 2 site only:** open a column to see its column lineage. Column lineage shows the source columns of a column and each change on the path.

## Data layers

The project has four layers. Each layer has a colour in the lineage graph.

| Layer | Colour | Schema | Contents | Users |
|---|---|---|---|---|
| Raw | Bronze | `raw` | Copies of the source data. No changes. | Data Platform team |
| Staging | Silver | `staging` | Clean source data: correct names, data types and units. One model for each raw table. | Data teams |
| Intermediate | Silver | `intermediate` | Joins and calculations that more than one mart uses. | Data teams |
| Marts | Gold | `marts` | Tables for business users, reports and tools. | All employees with access |

## Data domains and owners

Each domain has an owner and a data steward. The owner is the team that is accountable for the data. The data steward is the person who approves changes to definitions.

| Domain | Owner | Data steward | Tables |
|---|---|---|---|
| Sales | Sales Operations (sales-ops@jaffle-shop.example) | Head of Sales Operations | `orders`, `order_items`, `products` |
| Customers | Customer Insights (customer-insights@jaffle-shop.example) | Customer Insights Lead | `customers`, `customer_segments`, `customer_cohorts` |
| Finance | Finance (finance@jaffle-shop.example) | Financial Controller | `payments`, `monthly_revenue` |
| Marketing | Marketing (marketing@jaffle-shop.example) | Marketing Analytics Manager | `marketing_channel_performance`, `crm_audience` |
| Platform | Data Platform team (data-platform@jaffle-shop.example) | Data Platform Lead | All tables in `raw`, `staging` and `intermediate` |

## Data classification

Each table and each sensitive column has a classification level.

| Level | Meaning | Examples | Rule |
|---|---|---|---|
| Public | Data that can go outside the company. | Product names, list prices | No restrictions. |
| Internal | Data for all employees. | Order counts, order status | Do not share outside the company. |
| Confidential | Data for named teams only. | Revenue, cost, margin, marketing spend | Share only with the teams that need it. |
| Restricted | Personal data (PII). | Name, email address, phone number, postcode | Use only with a business need. The privacy officer must approve each new use. |

How to find personal data:

- The table metadata (`meta`) shows `contains_pii: true`.
- The column has the tag `pii` and the metadata `classification: restricted`.
- The column has a classifier, for example `pii.email`. The dbt 2 site shows classifiers.

## Access levels

The access level controls which models can use a model.

| Access | Meaning |
|---|---|
| `public` | All models can use it. Other dbt projects can also use it. |
| `protected` | Only models in this project can use it. |
| `private` | Only models of the same group can use it. |

## Metadata on each table

| Key | Meaning |
|---|---|
| `group` | The team that owns the table. |
| `domain` | The business domain of the table. |
| `data_steward` | The person who approves changes to the definitions. |
| `classification` | The highest classification level of the columns in the table. |
| `contains_pii` | `true` if the table contains personal data. |
| `certified` | `true` if the owner approves the table as a trusted source for reports. |

## Data quality

dbt runs the data tests each time it updates the data. Each test has a severity.

| Severity | Result if the test fails |
|---|---|
| `error` | The update stops. The tables keep the data of the previous update. |
| `warn` | The update continues. The Data Platform team examines the problem. |

**Known data issues**

| Issue | Tables | Test | Status |
|---|---|---|---|
| Some customers have no state. The web shop did not require the state before 2024-04-01. | `stg_customers`, `customers` | `not_null` on `state_code` (warn) | Accepted. No fix in the source. |

## Update schedule

| Time (AEST) | Step |
|---|---|
| 02:00 | The web shop sends its daily extract. |
| 04:00 | The payment service provider sends its settlement file. |
| 05:00 | dbt updates all tables and runs all tests. |
| 06:00 | The dashboards update. |
| 07:00 | The CRM tool gets the new `crm_audience`. |

The marketing team uploads the marketing spend on the 5th working day of each month.

## Key terms

| Term | Definition |
|---|---|
| Gross sales | Quantity multiplied by the unit price. Before discounts. Includes GST. |
| Discount | The coupon discount on an order line. |
| Net sales | Gross sales minus discounts. Excludes the shipping fee. Includes GST. |
| Order total | Net sales plus the shipping fee. The customer pays this amount. |
| Net order value | Order total minus refunds. |
| Net revenue | Net sales plus shipping fees minus refunds, without GST and without gift card sales. Finance uses this value for reports. |
| Gross margin | Net sales without GST minus the cost of goods sold. |
| GST | Goods and Services Tax. 10% in Australia. Prices to customers include GST. |
| Lifetime value (LTV) | The total net order value of a customer since the first order. |
| Average order value (AOV) | The mean order total of a customer. |
| Customer acquisition cost (CAC) | Marketing spend of a channel divided by the number of new customers from that channel. |
| First-order ROAS | First-order revenue of new customers divided by the marketing spend. ROAS means "return on ad spend". |
| Retention rate | The percentage of a cohort that orders again in a given month. |
| RFM | Recency, frequency and monetary value. A method to put customers into segments. |
| Active customer | A customer with an order in the last 180 days. |

## About this project

- The company, the customers and the data are fictional. The script `scripts/generate_seeds.py` makes the data.
- In production, the raw data comes from the source systems. In this project, CSV files (seeds) give the same data.
- The project starts from the [jaffle_shop](https://github.com/dbt-labs/jaffle_shop_duckdb) project of dbt Labs.

{% enddocs %}
