with source as (

    select * from {{ ref('raw_marketing_spend') }}

),

renamed as (

    select
        month as spend_month,
        -- The spreadsheet has display names ('Paid social'). The web shop has codes ('paid_social').
        {{ clean_text_code('channel') }} as acquisition_channel,
        spend_aud as spend_amount

    from source

)

select * from renamed
