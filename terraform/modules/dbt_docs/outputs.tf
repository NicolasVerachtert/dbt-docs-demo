output "urls" {
  description = "Public URL of each docs site."
  value       = { for k, s in azurerm_static_web_app.docs : k => "https://${s.default_host_name}" }
}
