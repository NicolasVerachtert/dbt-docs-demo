{#-
    Use the custom schema name as it is: raw, staging, intermediate, marts.
    The default dbt macro adds the target schema as a prefix (main_staging).
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
