terraform {
  required_version = ">= 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.9"
    }
  }
}

# Free tier: no cost, no overage billing possible.
resource "azurerm_static_web_app" "docs" {
  for_each = local.sites

  name                = "swa-${local.name}-${each.key}${local.env_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_tier            = "Free"
  sku_size            = "Free"

  # deploy-swa.yml finds the site by its `site` tag, so the workflows don't
  # need to know the resource names.
  tags = {
    site        = each.key
    dbt_version = each.value
    environment = var.environment
    managed_by  = "terraform"
  }
}
