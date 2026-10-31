// Deploys a hardened Azure Key Vault into an existing resource group:
//   - purge protection on, soft delete retention 90 days
//   - public network access disabled, reachable only through a private endpoint
//   - optional registration in an existing privatelink.vaultcore.azure.net DNS zone
//   - audit logs and metrics sent to an existing Log Analytics workspace
//
// Deploy with: az deployment group create --resource-group <rg> --parameters main.bicepparam

targetScope = 'resourceGroup'

// ---------- Parameters ----------

@description('Azure region for all resources. Must match the region of the private endpoint subnet.')
param location string = resourceGroup().location

@description('Name of the key vault (3-24 chars, globally unique, letters, digits and single hyphens)')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Key vault SKU. Use premium for HSM-backed keys.')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@description('Resource ID of an existing subnet for the key vault private endpoint (must be in the same region as location)')
param privateEndpointSubnetId string

@description('Resource ID of an existing privatelink.vaultcore.azure.net private DNS zone. Leave empty to skip DNS registration.')
param privateDnsZoneId string = ''

@description('Resource ID of an existing Log Analytics workspace that receives the key vault logs and metrics')
param logAnalyticsWorkspaceId string

@description('Object IDs of users, groups or service principals to grant the Key Vault Administrator role. Leave empty to manage access separately.')
param keyVaultAdminPrincipalIds array = []

@description('Tags applied to all resources')
param tags object = {}

// ---------- Variables ----------

// Built-in role: Key Vault Administrator
var keyVaultAdministratorRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'

var privateEndpointNicName = 'nic-pe-${keyVaultName}'

// ---------- Resources ----------

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: skuName
    }

    // Security baseline (not parameterised so every team gets the same settings)
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    enableRbacAuthorization: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

resource adminRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principalId in keyVaultAdminPrincipalIds: {
    name: guid(keyVault.id, principalId, keyVaultAdministratorRoleId)
    scope: keyVault
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdministratorRoleId)
      principalId: principalId
    }
  }
]

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-${keyVaultName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    customNetworkInterfaceName: privateEndpointNicName
    privateLinkServiceConnections: [
      {
        name: 'psc-${keyVaultName}'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

// Only register DNS when a zone is provided
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (!empty(privateDnsZoneId)) {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${keyVaultName}'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// The private endpoint's NIC, looked up by the fixed name set above so its IP can be output
resource privateEndpointNic 'Microsoft.Network/networkInterfaces@2024-05-01' existing = {
  name: privateEndpointNicName
}

// ---------- Outputs ----------

output resourceGroupName string = resourceGroup().name
output keyVaultId string = keyVault.id
output keyVaultUri string = keyVault.properties.vaultUri
output privateEndpointIp string = privateEndpointNic.properties.ipConfigurations[0].properties.privateIPAddress
