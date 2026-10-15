output "resource_group_name" {
  description = "Resource group of the sites."
  value       = data.azurerm_resource_group.dbt_docs.name
}

output "site_names" {
  description = "Resource name of each site (v1, v2)."
  value       = module.dbt_docs.names
}

output "urls" {
  description = "Public URL of each site (v1, v2)."
  value       = module.dbt_docs.urls
}
