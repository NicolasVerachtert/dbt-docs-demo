# jaffle_shop docs: dbt v1 vs dbt v2 on Azure

The classic [jaffle_shop](https://github.com/dbt-labs/jaffle_shop_duckdb) dbt project
(DuckDB, no warehouse), with its documentation built twice and hosted on two Azure
Static Web Apps:

| | v1 site | v2 site |
|---|---|---|
| dbt | dbt-core **1.11** + dbt-duckdb (the version dbt-fabric supports) | dbt **2.0** (Fusion engine), DuckDB built in |
| Pipeline | `.github/workflows/docs-v1.yml` | `.github/workflows/docs-v2.yml` |
| Docs output | One self-contained HTML file (`dbt docs generate --static`, ~2.5 MB) | dbt Docs v2: a single-page app + Parquet metadata (~350 files, ~13 MB) |
| Column-level lineage | No | Yes (`--static-analysis strict`) |
| Needs internet when viewed | No | Yes: loads DuckDB-WASM from jsDelivr and an extension from `extensions.duckdb.org` |

```
 you, once ─▶ terraform/bootstrap   terraform apply (local state)
                                    resource groups · state storage · 2 GitHub OIDC
                                    identities · role assignments · GitHub repo variables

 push main ─▶ deploy-pro.yml ─▶ deploy.yml: terraform/environments/pro apply (remote state)
                                            ─▶ build-v1 + build-v2 ─┐
 PR ────────▶ preview.yml ───────────────────▶ build-v1 + build-v2 ─┤
                                                                    ▼
                              deploy-swa.yml (shared): OIDC login ─▶ find the site by tag
                              ─▶ read deploy token ─▶ upload to that site (or PR preview)
```

Both pipelines build the **same** project. The YAML uses `data_tests:` and nested
`arguments:`, which both 1.11 and v2 accept.

## Layout

| Path | What it is |
|---|---|
| `jaffle_shop/` | The dbt project (from dbt-labs/jaffle_shop_duckdb, Apache 2.0) |
| `pyproject.toml`, `uv.lock`, `.python-version` | The dbt v1 toolchain, managed by uv |
| `terraform/bootstrap/` | Everything the pipeline needs before it can run Terraform itself. Applied once from your laptop |
| `terraform/modules/dbt_docs/` | The two Static Web Apps |
| `terraform/environments/pro/` | Calls the module for `pro`, with remote state. Applied by CI |
| `.github/workflows/deploy-pro.yml` | On `main`: calls `deploy.yml` for `pro` |
| `.github/workflows/deploy.yml` | Reusable: Terraform apply, then build and deploy both sites |
| `.github/workflows/preview.yml` | On pull requests: build both sites and deploy previews |
| `.github/workflows/build-v1.yml`, `build-v2.yml` | Reusable: one build per dbt version |
| `.github/workflows/deploy-swa.yml` | Reusable deploy step every pipeline calls |
| `web/staticwebapp.config.json` | Static Web Apps config: security headers, MIME types for the v2 Parquet files |

---

## Step by step

### 0. Install the tools

```bash
brew install azure-cli gh uv hashicorp/tap/terraform
```

### 1. Run both dbt versions locally

Both versions are called `dbt`, so keep them apart: v1 lives in the project's
`.venv` (`uv run dbt`), v2 runs as a separate tool (`uvx`).

```bash
uv sync                                   # Python 3.12 + dbt-core 1.11 into .venv
cd jaffle_shop

# dbt v1 (1.11)
uv run dbt build                          # expect PASS=28
uv run dbt docs generate
uv run dbt docs serve                     # http://localhost:8080

# dbt v2
uvx --from dbt==2.0.8 dbt build --write-index --static-analysis strict
uvx --from dbt==2.0.8 dbt docs serve      # http://localhost:8580
```

Both write to the same `jaffle_shop.duckdb` and `target/`. Run `rm -rf target` when
you switch versions, so neither picks up the other's artifacts.

### 2. Log in and create an empty repo

```bash
az login --tenant <tenant>.onmicrosoft.com
gh auth login
gh repo create jaffle-docs-azure --public
```

Don't push yet: the workflows need the repo variables from step 3.

### 3. Bootstrap

```bash
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # fill in tenant, subscription, GitHub user and repo
terraform init
terraform plan                                 # read it: 20 resources
terraform apply
```

This creates:

- Resource group `rg-jaffle-docs`, empty. The pipeline fills it.
- Resource group `rg-jaffle-docs-tfstate` with storage account `stjaffledocstfstate` and
  container `tfstate`. This is where `terraform/environments/*` keep their state.
  Storage account names are globally unique; if that one is taken, change it in
  `bootstrap/main.tf` and in the backend block of `environments/pro/main.tf`.
- Two Entra app registrations that trust GitHub tokens from **this repo only**
  (OIDC: no client secret):
  - `gh-jaffle-docs-deployer`, for `main`: Contributor on `rg-jaffle-docs` and
    Storage Blob Data Contributor on the state account.
  - `gh-jaffle-docs-previewer`, for pull requests: a custom role on `rg-jaffle-docs`
    that can find a site and read its deployment token, and nothing else.
- Storage Blob Data Contributor for **you** on the state account, so you can run
  `terraform plan` against the remote state from your laptop.
- Five GitHub Actions repo variables (`AZURE_CLIENT_ID`, `AZURE_PREVIEW_CLIENT_ID`,
  `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`). They're
  variables, not secrets: an ID grants nothing without a token GitHub only issues to
  this repo's workflows.

**About the bootstrap state file.** `terraform/bootstrap/terraform.tfstate` stays on
your laptop and is gitignored. It contains the state storage account's access keys,
so treat it like a password and back it up. If you lose it, Terraform forgets it
manages these resources (you'd `terraform import` them or delete and recreate). The
`pro` state lives in the storage account, with blob versioning on.

### 4. Push

```bash
cd ../..
git init -b main
git add . && git commit -m "Initial commit"
git remote add origin git@github.com:<you>/jaffle-docs-azure.git
git push -u origin main
```

**Deploy to PRO** starts. It applies `terraform/environments/pro`, which creates the
two Static Web Apps (Free tier) `swa-jaffle-docs-v1` and `swa-jaffle-docs-v2`, builds
both sites, and deploys each with `deploy-swa.yml`. The job summaries show the URLs.

To look at the `pro` state from your laptop:

```bash
cd terraform/environments/pro
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
terraform init
terraform output urls
```

### 5. Try a PR preview

```bash
git switch -c better-descriptions
# edit a description in jaffle_shop/models/schema.yml
git commit -am "Improve descriptions" && git push -u origin HEAD
gh pr create --fill
```

**Preview** builds both sites and posts two preview URLs as PR comments, one per dbt
version. It doesn't run Terraform, so the sites must already exist (step 4). Merging
runs Deploy to PRO; closing the PR removes the previews. The Free plan allows 3
previews per site, so close stale PRs.

### 6. Tear down

Destroy the sites first. Their state lives in the storage account that bootstrap is
about to delete.

```bash
cd terraform/environments/pro
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
terraform init
terraform destroy
cd ../../bootstrap && terraform destroy
```

---

## Design notes

- **No stored secrets.** GitHub's OIDC token is exchanged for an Entra token; each
  site's deployment token is read at deploy time and masked. (The portal's
  generated workflow stores that token as a GitHub secret instead.)
- **Least privilege.** The deployer (`main` only) can manage `rg-jaffle-docs` and its
  own state, and nothing else in the subscription. The previewer (pull requests, where
  anyone with push access can change what runs) can only read deployment tokens.
  Neither can change its own permissions: those live in the bootstrap state, which
  only you have.
- **Terraform before code.** `deploy.yml` applies Terraform before it deploys, so
  infrastructure changes and the site that needs them ship in one run. Deploys queue
  instead of cancelling each other, so an apply is never interrupted.
- **Tests gate deploys.** `dbt build` runs the tests; a failure stops the deploy.
- **Build once, deploy that artifact.** Build and deploy are separate jobs; the
  deploy ships exactly what was built.
- **No telemetry.** `DO_NOT_TRACK=1` turns off usage stats in both CLIs and in both
  published sites.
- **Reproducible.** `uv.lock` pins the v1 toolchain, `DBT_VERSION` pins v2, and the
  `.terraform.lock.hcl` files pin providers.

## Adding a `dev` environment

The layout follows the `modules/` + `environments/` split, so a second environment is
mostly a copy:

1. In `terraform/bootstrap`, add an `rg-jaffle-docs-dev` resource group and give both
   identities the same roles on it.
2. Copy `terraform/environments/pro` to `dev`: change the backend `key`, the resource
   group name and `environment = "dev"`. Site names get a `-dev` suffix.
3. Add a `deploy-dev.yml` that calls `deploy.yml` with `environment: dev`, and decide
   which ref deploys where (the reference project uses `main` for dev and `v*` tags for
   pro, which also needs a federated credential for tags).
4. `AZURE_RESOURCE_GROUP` is one repo variable today. Move it to GitHub environments,
   or pass it from `deploy.yml`, so each environment finds its own sites.

## Things to know

- **dbt v2 doesn't support Fabric.** Its adapters are Snowflake, BigQuery, Databricks,
  Redshift and DuckDB (Spark and ClickHouse in beta). Fabric stays on dbt v1, which is
  why the v1 pipeline is pinned to 1.11, the version Microsoft builds and tests
  dbt-fabric against.
- **dbt v2 comes in two distributions.** `dbt` (free, proprietary, downloaded from
  dbt Labs' CDN) and `dbt-oss` (Apache 2.0, on PyPI). `dbt-oss` has no static analysis
  engine, so its docs have no column-level lineage. The v2 pipeline uses `dbt`.
- **The v2 site needs internet in the viewer's browser** (jsDelivr and
  `extensions.duckdb.org`). Corporate networks that block those will see it stuck on
  "Loading…". The v1 site is fully self-contained.
- **The v2 site shows a "Collaborate with teams / Upgrade" panel** promoting the dbt
  platform.

## Troubleshooting

| Error | Cause / fix |
|---|---|
| `AADSTS700213: No matching federated identity record` | The workflow ran from a branch other than `main` or a PR. |
| `No Static Web App tagged site=v1` | Deploy to PRO hasn't run on `main` yet, or failed at the Terraform step. |
| `Could not read the deployment token` / `AuthorizationFailed` | A role assignment hasn't propagated yet (custom roles can take longer). Wait a few minutes and re-run. |
| `MissingSubscriptionRegistration` | Re-run `terraform apply` in `terraform/bootstrap`; it registers `Microsoft.Web`. |
| Backend `403` / `AuthorizationPermissionMismatch` on the state | Your Storage Blob Data Contributor role hasn't propagated yet, or you ran bootstrap as a different user. |
| `subscription_id is a required provider property` | Locally, set `ARM_SUBSCRIPTION_ID` before running Terraform in `environments/pro`. |
| `github` provider 401 / repo not found | Run `gh auth login`, check `terraform.tfvars`. The repo must exist first. |
| `Unsupported Terraform Core version` | You need Terraform 1.10 or later. Homebrew core stops at 1.5.7; use `hashicorp/tap/terraform`. |
| v2 site stuck on "Loading…" | The browser can't reach jsDelivr or `extensions.duckdb.org`. |
| v2: column lineage missing | You're running `dbt-oss`, or skipped `--static-analysis strict`. |
