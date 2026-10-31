# bicep-key-vault

Bicep template that deploys a hardened Azure Key Vault into an existing resource group.

## What you get

Every vault deployed from this template has the same security baseline. These settings are fixed in `main.bicep` and are not parameters:

- Purge protection on, soft delete retention of 90 days
- Public network access disabled, network ACLs default to `Deny` (trusted Azure services can bypass)
- A private endpoint in a subnet you supply
- Azure RBAC for data-plane access (no access policies)
- All logs and metrics sent to a Log Analytics workspace you supply

Optional:

- Registration of the private endpoint in an existing `privatelink.vaultcore.azure.net` private DNS zone
- Key Vault Administrator role for a list of users, groups or service principals

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) 2.53 or later, signed in with `az login`
- An existing resource group to deploy into
- An existing subnet for the private endpoint, in the same region as the vault
- An existing Log Analytics workspace
- Optional: an existing `privatelink.vaultcore.azure.net` private DNS zone linked to your VNet
- Permissions: Contributor on the resource group. If you set `keyVaultAdminPrincipalIds`, you also need Owner, User Access Administrator or Role Based Access Control Administrator.

## 1. Edit `main.bicepparam`

All deployment settings live in `main.bicepparam`.

| Parameter | Required | What to set it to |
|-----------|----------|-------------------|
| `location` | No | Azure region, e.g. `eastus`. Defaults to the resource group's region. Must match the private endpoint subnet's region. |
| `keyVaultName` | Yes | Name of the vault. Must be **globally unique** across Azure, 3–24 characters, start with a letter, and contain only letters, numbers and single hyphens. |
| `skuName` | No | `standard` (default) or `premium` for HSM-backed keys. |
| `privateEndpointSubnetId` | Yes | Resource ID of the subnet for the private endpoint. Find it with `az network vnet subnet show -g <vnet-rg> --vnet-name <vnet> -n <subnet> --query id -o tsv`. |
| `privateDnsZoneId` | No | Resource ID of an existing `privatelink.vaultcore.azure.net` zone. Leave as `''` to skip, for example when your platform team registers DNS centrally through Azure Policy. |
| `logAnalyticsWorkspaceId` | Yes | Resource ID of the workspace. Find it with `az monitor log-analytics workspace show -g <law-rg> -n <workspace> --query id -o tsv`. |
| `keyVaultAdminPrincipalIds` | No | Object IDs to grant **Key Vault Administrator**. Your own is `az ad signed-in-user show --query id -o tsv`. Defaults to none. |
| `tags` | No | Tags applied to the vault and private endpoint. |

The subnet, DNS zone and workspace can be in other resource groups or subscriptions, as long as you have permission to use them.

## 2. Deploy

```bash
az account set --subscription <subscription-id>
az group create --name <resource-group> --location eastus   # skip if it already exists

az deployment group create \
  --resource-group <resource-group> \
  --parameters main.bicepparam
```

To preview changes first, run `az deployment group what-if` with the same arguments.

When it finishes, the deployment outputs the vault's resource ID and URI and the private endpoint's IP address.

## Notes

- **Purge protection is on.** After a vault is deleted, its name can't be reused for 90 days. Pick a new `keyVaultName` if you delete and redeploy.
- **The vault is only reachable from the private network.** To manage secrets, connect from a machine that can reach the private endpoint, and make sure it resolves the vault's name to the private IP.
- **If you skip `privateDnsZoneId`,** clients will resolve the vault to its public IP and be refused. Add an A record for `<keyVaultName>` pointing to the `privateEndpointIp` output in whatever DNS your network uses.
