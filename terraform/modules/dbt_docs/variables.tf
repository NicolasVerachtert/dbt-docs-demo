variable "resource_group_name" {
  description = "Name of the resource group for the sites."
  type        = string
}

variable "location" {
  description = "Azure region of the Static Web Apps. Azure serves the sites from a global network."
  type        = string

  validation {
    condition     = contains(["westeurope", "westus2", "centralus", "eastus2", "eastasia"], var.location)
    error_message = "Use a Static Web Apps region: westeurope, westus2, centralus, eastus2 or eastasia."
  }
}

variable "environment" {
  description = "Name of the environment: dev or pro."
  type        = string

  validation {
    condition     = contains(["dev", "pro"], var.environment)
    error_message = "Use dev or pro."
  }
}
