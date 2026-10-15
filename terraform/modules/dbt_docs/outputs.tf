output "names" {
  description = "Resource name of each site (v1, v2)."
  value       = { for k, s in azurerm_static_web_app.docs : k => s.name }
}

output "urls" {
  description = "Public URL of each site (v1, v2)."
  value       = { for k, s in azurerm_static_web_app.docs : k => "https://${s.default_host_name}" }
}
