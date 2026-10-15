terraform {
  required_version = ">= 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.9"
    }
  }

  # Created by terraform/bootstrap.
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

  # The pipeline identity only has Contributor on the resource group, so it
  # can't register resource providers. terraform/bootstrap already did.
  resource_provider_registrations = "none"
}

data "azurerm_resource_group" "dbt_docs" {
  name = "rg-jaffle-docs"
}

module "dbt_docs" {
  source = "../../modules/dbt_docs"

  resource_group_name = data.azurerm_resource_group.dbt_docs.name
  location            = data.azurerm_resource_group.dbt_docs.location
  environment         = "pro"
}
