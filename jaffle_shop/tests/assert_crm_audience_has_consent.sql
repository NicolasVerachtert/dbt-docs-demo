-- Each customer in `crm_audience` agrees to receive marketing email.
-- The CRM tool must not get a customer without consent.

select crm_audience.customer_id

from {{ ref('crm_audience') }} as crm_audience

left join {{ ref('customers') }} as customers
    on crm_audience.customer_id = customers.customer_id

where customers.is_marketing_opt_in is distinct from true
