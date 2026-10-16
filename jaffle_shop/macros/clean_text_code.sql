{#- Change free text to a code: 'Paid social ' becomes 'paid_social'. -#}
{% macro clean_text_code(column_name) -%}
    replace(lower(trim({{ column_name }})), ' ', '_')
{%- endmacro %}
