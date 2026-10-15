variable "tenant_id" {
  description = "Entra tenant ID (GUID) the app registrations and Azure resources live in."
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID (GUID) the resources are created in."
  type        = string
}

variable "github_owner" {
  description = "GitHub user or organisation that owns the repo."
  type        = string
}

variable "github_repo" {
  description = "Repository name, without the owner. The repo must already exist."
  type        = string
}

variable "location" {
  description = "Region for the resource groups and the state storage account. The docs sites inherit it from their resource group."
  type        = string
  default     = "westeurope"

  # Checked here too, because a resource group's region can't be changed later.
  validation {
    condition     = contains(["westeurope", "westus2", "centralus", "eastus2", "eastasia"], var.location)
    error_message = "Static Web Apps is only available in westeurope, westus2, centralus, eastus2 and eastasia."
  }
}
