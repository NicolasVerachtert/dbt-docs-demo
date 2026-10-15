# jaffle_shop docs: dbt v1 and dbt v2 on Azure

This project builds the documentation of the
[jaffle_shop](https://github.com/dbt-labs/jaffle_shop_duckdb) dbt project two times: with
dbt v1 and with dbt v2. Two Azure Static Web Apps show the results.

| | v1 site | v2 site |
|---|---|---|
| dbt | dbt-core 1.11 and dbt-duckdb | dbt 2.0 (Fusion engine) |
| Docs | One HTML file (approximately 2.5 MB) | A web app with Parquet metadata (approximately 350 files, 13 MB) |
| Column-level lineage | No | Yes |
| Internet access in the browser | Not necessary | Necessary (jsDelivr and `extensions.duckdb.org`) |

## Layout

| Path | Contents |
|---|---|
| `jaffle_shop/` | The dbt project (from dbt-labs/jaffle_shop_duckdb, Apache 2.0) |
| `terraform/modules/dbt_docs/` | The two Static Web Apps |
| `terraform/environments/pro/` | The `pro` environment. The pipeline applies it. |
| `.github/workflows/deploy.yml` | The pipeline |
| `web/staticwebapp.config.json` | Security headers and MIME types for the sites |

## Pipeline

A push to `main` starts `deploy.yml`:

1. The `terraform` job applies `terraform/environments/pro`.
2. At the same time, the `build-v1` and `build-v2` jobs build the sites. If a dbt test
   fails, the pipeline stops.
3. The `deploy` job gets the deployment token of each site and uploads the site.

The pipeline uses OIDC to log in to Azure. GitHub does not keep a password or a token.

## Run dbt on your computer

1. Install the tools:

   ```bash
   brew install azure-cli gh uv hashicorp/tap/terraform
   ```

2. Make an alias for each dbt version. The two versions use the same command name,
   `dbt`. `uvx` keeps them separate. Use the same versions as in `deploy.yml`.

   ```bash
   alias dbt1='uvx --python 3.12 --from dbt-core==1.11.15 --with dbt-duckdb==1.11.0 dbt'
   alias dbt2='uvx --from dbt==2.0.8 dbt'
   ```

3. Build and show the docs:

   ```bash
   cd jaffle_shop

   dbt1 build                  # Expect PASS=28.
   dbt1 docs generate
   dbt1 docs serve             # http://localhost:8080

   rm -rf target               # Remove the v1 output before you use v2.
   dbt2 build --write-index --static-analysis strict
   dbt2 docs serve             # http://localhost:8580
   ```

## Set up Azure

Do this procedure one time, before the first push. You must have the Owner role on the
subscription. You must also have permission to create app registrations in Entra ID.

1. Log in:

   ```bash
   az login --tenant <tenant>.onmicrosoft.com
   gh auth login
   ```

2. Create the GitHub repository. Do not push yet.

   ```bash
   gh repo create dbt-docs-demo --public
   ```

3. Create the Azure resources and the repository variables:

   ```bash
   LOCATION=belgiumcentral              # The sites use eastus2. Refer to terraform/environments/pro/main.tf.
   REPO=<owner>/<repo>
   # GitHub sends this prefix in the OIDC subject, for example repo:<owner>@<owner-id>/<repo>@<repo-id>.
   SUBJECT_PREFIX=$(gh api "repos/$REPO/actions/oidc/customization/sub" --jq .sub_claim_prefix)
   TENANT_ID=$(az account show --query tenantId -o tsv)
   SUBSCRIPTION_ID=$(az account show --query id -o tsv)

   # Let the subscription create Static Web Apps.
   az provider register --namespace Microsoft.Web

   # Resource groups for the sites and for the Terraform state.
   az group create -n rg-jaffle-docs -l "$LOCATION"
   az group create -n rg-jaffle-docs-tfstate -l "$LOCATION"

   # Storage for the Terraform state. Storage account names are globally unique.
   # If the name is not available, change it here and in terraform/environments/pro/main.tf.
   az storage account create -n stjaffledocstfstate -g rg-jaffle-docs-tfstate -l "$LOCATION" \
     --sku Standard_LRS --min-tls-version TLS1_2 --allow-blob-public-access false
   az storage account blob-service-properties update \
     --account-name stjaffledocstfstate -g rg-jaffle-docs-tfstate --enable-versioning true
   az storage container-rm create --storage-account stjaffledocstfstate \
     -g rg-jaffle-docs-tfstate -n tfstate

   # The CI identity. It accepts GitHub OIDC tokens from the main branch of this repository only.
   APP_ID=$(az ad app create --display-name gh-jaffle-docs-deployer --query appId -o tsv)
   SP_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv)
   cat > federated-credential.json <<EOF
   {
     "name": "github-main",
     "issuer": "https://token.actions.githubusercontent.com",
     "subject": "${SUBJECT_PREFIX}:ref:refs/heads/main",
     "audiences": ["api://AzureADTokenExchange"]
   }
   EOF
   az ad app federated-credential create --id "$APP_ID" --parameters federated-credential.json
   rm federated-credential.json

   # The CI identity manages the sites and the state. You get access to the state.
   SITES_RG_ID=$(az group show -n rg-jaffle-docs --query id -o tsv)
   STATE_ID=$(az storage account show -n stjaffledocstfstate -g rg-jaffle-docs-tfstate --query id -o tsv)
   az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
     --role Contributor --scope "$SITES_RG_ID"
   az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
     --role "Storage Blob Data Contributor" --scope "$STATE_ID"
   az role assignment create --assignee "$(az ad signed-in-user show --query id -o tsv)" \
     --role "Storage Blob Data Contributor" --scope "$STATE_ID"

   # Repository variables. These are IDs, not secrets.
   gh variable set AZURE_CLIENT_ID --body "$APP_ID" -R "$REPO"
   gh variable set AZURE_TENANT_ID --body "$TENANT_ID" -R "$REPO"
   gh variable set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" -R "$REPO"
   ```

## Deploy

1. Push to `main`:

   ```bash
   git remote add origin git@github.com:<owner>/dbt-docs-demo.git
   git push -u origin main
   ```

2. Read the URLs in the summary of the Deploy run.

To deploy again without a change, start the Deploy workflow manually on the Actions tab.

To read the URLs from your computer:

```bash
cd terraform/environments/pro
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
terraform init
terraform output urls
```

## Test a Terraform change

Do this before you push a change in `terraform/`:

```bash
terraform fmt -check -recursive terraform
cd terraform/environments/pro
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
terraform validate
terraform plan
```

## Remove everything

Destroy the sites first. Their state is in the storage account.

```bash
cd terraform/environments/pro
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
terraform init
terraform destroy
az group delete -n rg-jaffle-docs
az group delete -n rg-jaffle-docs-tfstate
az ad app delete --id <AZURE_CLIENT_ID>
```

## Add a dev environment

1. Create the resource group `rg-jaffle-docs-dev`. Give the CI identity the Contributor
   role on it.
2. Copy `terraform/environments/pro` to `terraform/environments/dev`. Change the backend
   `key`, the resource group name, and `environment = "dev"`.
3. Select the Git ref that deploys to dev, for example `main`. Select a different ref for
   pro, for example `v*` tags. Add a federated credential for each ref.
4. Change `deploy.yml` to a reusable workflow with an `environment` input. Call it from
   `deploy-dev.yml` and `deploy-pro.yml`.

## Known limits

- dbt v2 does not support Microsoft Fabric. Thus, the v1 site uses dbt-core 1.11. This
  is the version that dbt-fabric supports.
- dbt v2 has two distributions: `dbt` and `dbt-oss`. Only `dbt` shows column-level
  lineage. The pipeline uses `dbt`.
- The v2 site loads files from jsDelivr and `extensions.duckdb.org`. If a network blocks
  these sites, the v2 site stops at "Loading…".
- The v2 site shows an "Upgrade" panel for the dbt platform.

## Troubleshooting

| Error | Cause and fix |
|---|---|
| `AADSTS700213: No matching federated identity record` | The workflow did not run from `main`, or the subject of the federated credential is not the same as the subject from GitHub. Compare the subject with the `sub_claim_prefix` from `gh api repos/<owner>/<repo>/actions/oidc/customization/sub`. |
| `Cannot read the deployment token` or `AuthorizationFailed` | Azure did not apply a role assignment yet. Wait some minutes and run the workflow again. |
| `MissingSubscriptionRegistration` | `Microsoft.Web` is not registered. Run `az provider register --namespace Microsoft.Web`. |
| `403` or `AuthorizationPermissionMismatch` on the state | Azure did not apply the Storage Blob Data Contributor role yet. Wait some minutes. |
| `subscription_id is a required provider property` | Set `ARM_SUBSCRIPTION_ID` before you run Terraform on your computer. |
| `RequestDisallowedByAzure`: the region is not accepting new customers | The subscription cannot use this region. Select a different region. |
| `Unsupported Terraform Core version` | Use Terraform 1.10 or later. Homebrew core has 1.5.7. Use `hashicorp/tap/terraform`. |
| No column-level lineage on the v2 site | Use `dbt`, not `dbt-oss`, and use `--static-analysis strict`. |
