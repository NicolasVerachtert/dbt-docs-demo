# Applied once from your laptop with `terraform apply`. It creates what the
# pipeline needs before it can run terraform/environments itself.
#
# State is local (terraform.tfstate in this folder, gitignored). It contains the
# state storage account's access keys, so treat that file like a password and
# don't lose it.

terraform {
  required_version = ">= 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.9"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }
}

# Authenticates with your `az login` session, but always targets the tenant and
# subscription in terraform.tfvars, whatever `az account show` says.
provider "azurerm" {
  features {}

  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  # Register only what this project uses. The pipeline can't register providers
  # itself, so Microsoft.Web (Static Web Apps) is registered here for it.
  resource_provider_registrations = "none"
  resource_providers_to_register  = ["Microsoft.Storage", "Microsoft.Web"]
}

# Entra ID: the app registrations GitHub Actions logs in as.
provider "azuread" {
  tenant_id = var.tenant_id
}

# Uses GITHUB_TOKEN if set, otherwise your `gh auth login` session.
provider "github" {
  owner = var.github_owner
}
