with source as (

    {#-
    Normally we would select from the table here, but we are using seeds to load
    our data in this project
    #}
    select * from {{ ref('raw_customers') }}

),

states as (

    select * from {{ ref('au_states') }}

),

renamed as (

    select
        id as customer_id,
        first_name,
        last_name,
        lower(trim(email)) as email,
        -- Keep the digits only, then write the number in E.164 format: +61412345678.
        case
            when phone is null then null
            when regexp_replace(phone, '[^0-9]', '', 'g') like '61%'
                then '+' || regexp_replace(phone, '[^0-9]', '', 'g')
            else '+61' || substr(regexp_replace(phone, '[^0-9]', '', 'g'), 2)
        end as phone,
        city,
        upper(trim(state)) as state_raw,
        postcode,
        acquisition_channel,
        marketing_opt_in as is_marketing_opt_in,
        created_at,
        cast(created_at as date) as signup_date

    from source

),

final as (

    select
        renamed.customer_id,
        renamed.first_name,
        renamed.last_name,
        renamed.email,
        renamed.phone,
        renamed.city,
        -- The raw state can be the code (NSW) or the name (New South Wales).
        coalesce(state_by_code.state_code, state_by_name.state_code) as state_code,
        renamed.postcode,
        renamed.acquisition_channel,
        renamed.is_marketing_opt_in,
        renamed.created_at,
        renamed.signup_date

    from renamed

    left join states as state_by_code
        on renamed.state_raw = upper(state_by_code.state_code)

    left join states as state_by_name
        on renamed.state_raw = upper(state_by_name.state_name)

)

select * from final
