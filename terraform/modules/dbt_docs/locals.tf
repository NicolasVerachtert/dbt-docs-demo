locals {
  name = "jaffle-docs"

  env_suffix = var.environment == "pro" ? "" : "-${var.environment}"

  # One site per dbt version. Each pipeline deploys to its own site; two
  # pipelines deploying to one site would overwrite each other.
  sites = {
    v1 = "dbt v1 (1.11)"
    v2 = "dbt v2"
  }
}
