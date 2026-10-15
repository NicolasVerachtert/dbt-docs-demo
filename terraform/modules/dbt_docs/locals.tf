locals {
  name = "jaffle-docs"

  env_suffix = var.environment == "pro" ? "" : "-${var.environment}"

  # One site for each dbt version.
  sites = {
    v1 = "dbt v1 (1.11)"
    v2 = "dbt v2"
  }
}
