variable "resource_group_name" {
  description = "Name of the resource group to deploy to."
  type        = string
}

variable "location" {
  description = "Azure region for the Static Web App resources. The sites themselves are served from a global edge network."
  type        = string

  validation {
    condition     = contains(["westeurope", "westus2", "centralus", "eastus2", "eastasia"], var.location)
    error_message = "Static Web Apps is only available in westeurope, westus2, centralus, eastus2 and eastasia."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "pro"], var.environment)
    error_message = "Invalid environment"
  }
}
