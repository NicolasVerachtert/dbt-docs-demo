terraform {
  required_version = ">= 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.9"
    }
  }

  # You create these resources manually. Refer to the README.
  backend "azurerm" {
    resource_group_name  = "rg-jaffle-docs-tfstate"
    storage_account_name = "stjaffledocstfstate"
    container_name       = "tfstate"
    key                  = "pro.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}

  # The CI identity cannot register resource providers. You register Microsoft.Web manually.
  resource_provider_registrations = "none"
}

data "azurerm_resource_group" "dbt_docs" {
  name = "rg-jaffle-docs"
}

module "dbt_docs" {
  source = "../../modules/dbt_docs"

  resource_group_name = data.azurerm_resource_group.dbt_docs.name
  environment         = "pro"

  # westeurope does not accept new subscriptions. Azure serves the sites from a global network.
  location = "eastus2"
}
