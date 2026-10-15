data "azurerm_client_config" "current" {}

# Fails early if the repo doesn't exist, and returns its exact name. GitHub's
# OIDC subject is case-sensitive, so this avoids "no matching federated identity
# record" errors caused by a typo in the repo name.
data "github_repository" "this" {
  full_name = "${var.github_owner}/${var.github_repo}"
}

locals {
  name = "jaffle-docs"
  repo = data.github_repository.this.full_name
}

# ---------------------------------------------------------------------------
# Resource groups. terraform/environments/pro reads these by name.
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "dbt_docs" {
  name     = "rg-${local.name}"
  location = var.location
}

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-${local.name}-tfstate"
  location = var.location
}

# ---------------------------------------------------------------------------
# Remote state for terraform/environments/*
# ---------------------------------------------------------------------------

# Storage account names are globally unique. If this one is taken, change it
# here and in the backend block of terraform/environments/*/main.tf.
resource "azurerm_storage_account" "tfstate" {
  name                            = "st${replace(local.name, "-", "")}tfstate"
  resource_group_name             = azurerm_resource_group.tfstate.name
  location                        = azurerm_resource_group.tfstate.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  # Earlier versions of a state file can be restored if one gets corrupted.
  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

# The backend authenticates with Entra ID, not the account key, and Owner
# doesn't include blob data access. This lets you run plan from your laptop.
resource "azurerm_role_assignment" "tfstate_you" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ---------------------------------------------------------------------------
# Identities GitHub Actions logs in as (OIDC: no client secret, no stored token)
#
# Two of them, because anyone who can open a pull request can change what its
# workflows run:
#   deployer  - main only. Runs Terraform and deploys the production sites.
#   previewer - pull requests. Can read the sites' deployment tokens, nothing else.
# ---------------------------------------------------------------------------

locals {
  identities = {
    deployer  = "repo:${local.repo}:ref:refs/heads/main"
    previewer = "repo:${local.repo}:pull_request"
  }
}

resource "azuread_application_registration" "github" {
  for_each = local.identities

  display_name = "gh-${local.name}-${each.key}"
}

resource "azuread_service_principal" "github" {
  for_each = local.identities

  client_id = azuread_application_registration.github[each.key].client_id
}

resource "azuread_application_federated_identity_credential" "github" {
  for_each = local.identities

  application_id = azuread_application_registration.github[each.key].id
  display_name   = "github-${each.key}"
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = each.value
  audiences      = ["api://AzureADTokenExchange"]
}

# Deployer: manage everything in the docs resource group, and read and write
# the state. Same as what the pipeline identity gets in the reference project.
resource "azurerm_role_assignment" "deployer" {
  for_each = {
    contributor = { scope = azurerm_resource_group.dbt_docs.id, role = "Contributor" }
    tfstate     = { scope = azurerm_storage_account.tfstate.id, role = "Storage Blob Data Contributor" }
  }

  scope                            = each.value.scope
  role_definition_name             = each.value.role
  principal_id                     = azuread_service_principal.github["deployer"].object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true # the service principal is brand new
}

# Previewer: find a site and read its deployment token. That's all a PR preview
# needs, so a PR can't change or delete anything.
resource "azurerm_role_definition" "previewer" {
  name        = "Static Web App previewer (${local.name})"
  description = "Find Static Web Apps and read their deployment tokens."
  scope       = azurerm_resource_group.dbt_docs.id

  permissions {
    actions = [
      "Microsoft.Web/staticSites/read",
      "Microsoft.Web/staticSites/listSecrets/action",
    ]
  }

  assignable_scopes = [azurerm_resource_group.dbt_docs.id]
}

resource "azurerm_role_assignment" "previewer" {
  scope                            = azurerm_resource_group.dbt_docs.id
  role_definition_id               = azurerm_role_definition.previewer.role_definition_resource_id
  principal_id                     = azuread_service_principal.github["previewer"].object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

# ---------------------------------------------------------------------------
# GitHub repo variables the workflows read
# ---------------------------------------------------------------------------

# Variables, not secrets: none of these grant anything on their own.
# Access comes from the federated credentials, which only trust this repo.
resource "github_actions_variable" "this" {
  for_each = {
    AZURE_CLIENT_ID         = azuread_application_registration.github["deployer"].client_id
    AZURE_PREVIEW_CLIENT_ID = azuread_application_registration.github["previewer"].client_id
    AZURE_TENANT_ID         = data.azurerm_client_config.current.tenant_id
    AZURE_SUBSCRIPTION_ID   = data.azurerm_client_config.current.subscription_id
    AZURE_RESOURCE_GROUP    = azurerm_resource_group.dbt_docs.name
  }

  repository    = data.github_repository.this.name
  variable_name = each.key
  value         = each.value
}
