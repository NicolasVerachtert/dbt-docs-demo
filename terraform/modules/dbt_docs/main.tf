terraform {
  required_version = ">= 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.9"
    }
  }
}

# The Free tier has no costs.
resource "azurerm_static_web_app" "docs" {
  for_each = local.sites

  name                = "swa-${local.name}-${each.key}${local.env_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_tier            = "Free"
  sku_size            = "Free"

  preview_environments_enabled = false

  tags = {
    site        = each.key
    dbt_version = each.value
    environment = var.environment
    managed_by  = "terraform"
  }

  # A deploy with the deployment token sets these values. Terraform must not reset them.
  lifecycle {
    ignore_changes = [repository_url, repository_branch]
  }
}
