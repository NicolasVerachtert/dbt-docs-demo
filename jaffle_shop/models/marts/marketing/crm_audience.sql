with customers as (

    select * from {{ ref('customers') }}

),

segments as (

    select * from {{ ref('customer_segments') }}

),

final as (

    select
        customers.customer_id,
        customers.first_name,
        customers.email,
        customers.state_code,
        customers.customer_status,
        coalesce(segments.rfm_segment, 'prospect') as rfm_segment,
        customers.most_recent_order_date,
        -- Do not send the exact lifetime value to the CRM tool. A band is sufficient.
        case
            when customers.lifetime_value = 0 then '0'
            when customers.lifetime_value < 100 then '1-99'
            when customers.lifetime_value < 250 then '100-249'
            when customers.lifetime_value < 500 then '250-499'
            else '500+'
        end as lifetime_value_band

    from customers

    left join segments
        on customers.customer_id = segments.customer_id

    -- Consent: send only the customers who agree to receive marketing email.
    where customers.is_marketing_opt_in

)

select * from final
