# jaffle_shop docs: dbt v1 and dbt v2 on Azure

This project builds the documentation of a jaffle_shop dbt project two times: with dbt v1
and with dbt v2. Two Azure Static Web Apps show the results.

The dbt project starts from
[jaffle_shop](https://github.com/dbt-labs/jaffle_shop_duckdb) and adds more models, data and
documentation. The audience is business users and data governance consultants.

| | v1 site | v2 site |
|---|---|---|
| dbt | dbt-core 1.11 and dbt-duckdb | dbt 2.0 (Fusion engine) |
| Docs | One HTML file (approximately 3 MB) | A web app with Parquet metadata (approximately 350 files, 12 MB) |
| Column-level lineage | No | Yes |
| Internet access in the browser | Not necessary | Necessary (jsDelivr and `extensions.duckdb.org`) |

## Layout

| Path | Contents |
|---|---|
| `jaffle_shop/` | The dbt project (from dbt-labs/jaffle_shop_duckdb, Apache 2.0) |
| `scripts/generate_seeds.py` | Makes the fictional raw data in `jaffle_shop/seeds/raw_*.csv` |
| `terraform/modules/dbt_docs/` | The two Static Web Apps |
| `terraform/environments/pro/` | The `pro` environment. The pipeline applies it. |
| `.github/workflows/deploy.yml` | The pipeline |
| `web/staticwebapp.config.json` | Security headers and MIME types for the sites |

## The dbt project

Jaffle Shop is a fictional Australian web shop. It sells jaffle irons, food, coffee and
merchandise. The data covers January 2024 to September 2026.

| Layer | Schema | Models |
|---|---|---|
| Raw (seeds) | `raw` | 7 raw extracts and 2 reference tables |
| Staging | `staging` | 7 models: clean names, types and units |
| Intermediate | `intermediate` | 3 models: order lines, payments and refunds |
| Marts | `marts` | 11 models in 4 domains: sales, customers, finance, marketing |

The project shows these dbt features:

| Feature | Where |
|---|---|
| Overview page, glossary, classification levels | `models/docs/overview.md` |
| Shared column definitions (`doc()`) | `models/docs/columns.md` |
| Groups (owners), access levels, `meta` | `models/_groups.yml`, `dbt_project.yml` |
| Model contracts | `orders`, `customers` |
| Private model | `customer_rfm_scores` |
| PII tags and classifiers (dbt v2 shows classifiers) | `stg_customers`, `customers`, `crm_audience` |
| Generic, singular and unit tests | `tests/`, the `_*.yml` files |
| Tests with `warn` severity for a known data issue | `state_code` in `stg_customers` |
| Exposures (dashboards, an application, an ML model) | `models/marts/_exposures.yml` |
| Column-level lineage (dbt v2 only) | All models |

To make the raw data again, run `uv run scripts/generate_seeds.py` from the repository
root. The script always makes the same data.

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

   dbt1 build                  # Expect PASS=161 WARN=2. The warnings are a known data issue.
   dbt1 docs generate
   dbt1 docs serve             # http://localhost:8080

   rm -rf target               # Remove the v1 output before you use v2.
   dbt2 build --write-index --static-analysis strict
   dbt2 docs serve             # http://localhost:8580
   ```

## Set up Azure and GitHub

Do this procedure one time, before the first push. You must have the Owner role on the
subscription. You must also have permission to create app registrations in Entra ID.

You create these items:

| Item | Name | Purpose |
|---|---|---|
| Resource provider | `Microsoft.Web` | Lets the subscription create Static Web Apps |
| Resource group | `rg-jaffle-docs` | Terraform creates the sites in this group |
| Resource group | `rg-jaffle-docs-tfstate` | Contains the state storage |
| Storage account and container | `stjaffledocstfstate`, `tfstate` | Contains the Terraform state |
| App registration | `gh-jaffle-docs-deployer` | The identity of the pipeline |
| Federated credential | `github-main` | Lets the pipeline log in from `main` without a secret |
| Role assignments | | Give access to the pipeline and to you |
| Repository variables | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` | Tell the pipeline which identity to use |

All items are free, except the storage account. It costs less than €0.01 each month. Do
not enable Microsoft Defender for Storage. It costs approximately $10 each month.

Some regions do not accept new subscriptions, for example `westeurope`. Then Azure shows
`RequestDisallowedByAzure`. Select a different region. The sites use `eastus2`. Refer to
`terraform/environments/pro/main.tf`.

### With the Azure portal and GitHub

1. Create the GitHub repository:
   1. On github.com, select **+** > **New repository**.
   2. Type the name `dbt-docs-demo`. Do not add a README, a .gitignore, or a license.
   3. Select **Create repository**. Do not push yet.

2. Get the IDs of your Azure account. In the Azure portal (portal.azure.com):
   1. Go to **Subscriptions** > your subscription > **Overview**. Copy the **Subscription ID**.
   2. Go to **Microsoft Entra ID** > **Overview**. Copy the **Tenant ID**.

3. Register the resource provider:
   1. Go to **Subscriptions** > your subscription > **Settings** > **Resource providers**.
   2. Find `Microsoft.Web`. If the status is not **Registered**, select it and select
      **Register**.

4. Create the resource groups:
   1. Go to **Resource groups** > **+ Create**.
   2. Type the name `rg-jaffle-docs`. Select a region, for example **Belgium Central**.
   3. Select **Review + create** > **Create**.
   4. Do steps 4.1 to 4.3 again for `rg-jaffle-docs-tfstate`.

5. Create the storage account:
   1. Go to **Storage accounts** > **+ Create**.
   2. On the **Basics** tab, set these values:
      - **Resource group**: `rg-jaffle-docs-tfstate`
      - **Storage account name**: `stjaffledocstfstate`
      - **Region**: for example **Belgium Central**
      - **Primary service**: **Azure Blob Storage or Azure Data Lake Storage Gen 2**
      - **Performance**: **Standard**
      - **Redundancy**: **Locally-redundant storage (LRS)**
   3. On the **Advanced** tab, disable **Enable hierarchical namespace** and **Allow
      enabling anonymous access on individual containers**. Make sure that **Minimum TLS
      version** is **1.2**.
   4. On the **Data protection** tab, enable **Enable versioning for blobs**.
   5. Select **Review + create** > **Create**.

   Storage account names are globally unique. If the name is not available, use a
   different name. Then change `storage_account_name` in
   `terraform/environments/pro/main.tf`.

6. Create the container:
   1. In the storage account, go to **Data storage** > **Containers** > **+ Container**.
   2. Type the name `tfstate`. Set **Anonymous access level** to **Private**.
   3. Select **Create**.

7. Give yourself access to the state. The Owner role does not give access to the data in
   a storage account.
   1. In the storage account, go to **Access control (IAM)** > **+ Add** > **Add role
      assignment**.
   2. On the **Role** tab, select **Storage Blob Data Contributor**. Select **Next**.
   3. On the **Members** tab, select **+ Select members**. Select your user.
   4. Select **Review + assign**.

8. Create the app registration:
   1. Go to **Microsoft Entra ID** > **App registrations** > **+ New registration**.
   2. Type the name `gh-jaffle-docs-deployer`.
   3. Select **Accounts in this organizational directory only (Single tenant)**. Do not
      add a redirect URI.
   4. Select **Register**.
   5. On the **Overview** page, copy the **Application (client) ID**.

9. Add the federated credential:
   1. Get the IDs of the GitHub owner and the repository. Open
      `https://api.github.com/repos/<owner>/<repo>` in a browser. The repository ID is
      `id`. The owner ID is `owner.id`.
   2. In the app registration, go to **Certificates & secrets** > **Federated
      credentials** > **+ Add credential**.
   3. For **Federated credential scenario**, select **GitHub Actions deploying Azure
      resources**.
   4. Type the organization (the GitHub owner), the repository, and their IDs.
   5. Set **Entity type** to **Branch** and **GitHub branch name** to `main`.
   6. Type the name `github-main`.
   7. Make sure that the **Subject identifier** is
      `repo:<owner>@<owner-id>/<repo>@<repo-id>:ref:refs/heads/main`. The subject is
      case-sensitive.
   8. Select **Add**.

10. Give the app registration access:
    1. Go to **Resource groups** > `rg-jaffle-docs` > **Access control (IAM)** > **+ Add**
       > **Add role assignment**.
    2. On the **Role** tab, select **Privileged administrator roles** > **Contributor**.
       Select **Next**.
    3. On the **Members** tab, select **+ Select members**. Select
       `gh-jaffle-docs-deployer`.
    4. Select **Review + assign**.
    5. Do steps 10.1 to 10.4 again on the storage account `stjaffledocstfstate`, with the
       role **Storage Blob Data Contributor**.

11. Add the repository variables:
    1. In the GitHub repository, go to **Settings** > **Secrets and variables** >
       **Actions** > **Variables**.
    2. Select **New repository variable**. Add these variables. They are IDs, not secrets.

       | Name | Value |
       |---|---|
       | `AZURE_CLIENT_ID` | Application (client) ID from step 8 |
       | `AZURE_TENANT_ID` | Tenant ID from step 2 |
       | `AZURE_SUBSCRIPTION_ID` | Subscription ID from step 2 |

### With the Azure CLI and the GitHub CLI

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
