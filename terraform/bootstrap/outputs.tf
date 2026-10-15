output "state_storage_account" {
  description = "Storage account holding the state of terraform/environments/*. Must match their backend blocks."
  value       = azurerm_storage_account.tfstate.name
}
