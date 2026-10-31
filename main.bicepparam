using 'main.bicep'

param location = 'eastus'
param keyVaultName = 'kv-test-ptzlabbicep1'
param skuName = 'standard'

// Existing subnet for the private endpoint (same region as location)
param privateEndpointSubnetId = '/subscriptions/<subscription-id>/resourceGroups/<vnet-rg>/providers/Microsoft.Network/virtualNetworks/<vnet-name>/subnets/<subnet-name>'

// Optional: existing privatelink.vaultcore.azure.net zone. Leave empty to set up DNS later.
param privateDnsZoneId = ''
// param privateDnsZoneId = '/subscriptions/<subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'

// Existing Log Analytics workspace for audit logs and metrics
param logAnalyticsWorkspaceId = '/subscriptions/<subscription-id>/resourceGroups/<law-rg>/providers/Microsoft.OperationalInsights/workspaces/<workspace-name>'

// Optional: object IDs to grant Key Vault Administrator (find yours with: az ad signed-in-user show --query id -o tsv)
param keyVaultAdminPrincipalIds = []

param tags = {
  environment: 'test'
  managed_by: 'bicep'
}
