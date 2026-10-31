// Deploys an Azure Key Vault into an existing resource group.
// Deploy with: az deployment group create --resource-group <rg> --parameters main.bicepparam

targetScope = 'resourceGroup'

// ---------- Parameters ----------

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Name of the key vault (3-24 chars, globally unique)')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Tags applied to all resources')
param tags object = {}

// ---------- Resources ----------

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    softDeleteRetentionInDays: 90
    enableSoftDelete: true
    enablePurgeProtection: true

    // Give whoever runs the deployment access to manage secrets/keys/certs
    accessPolicies: [
      {
        tenantId: deployer().tenantId
        objectId: deployer().objectId
        permissions: {
          secrets: ['get', 'list', 'set', 'delete', 'purge', 'recover']
          keys: ['get', 'list', 'create', 'delete', 'purge', 'recover']
          certificates: ['get', 'list', 'create', 'delete', 'purge', 'recover']
        }
      }
    ]
  }
}

// ---------- Outputs ----------

output resourceGroupName string = resourceGroup().name
output keyVaultUri string = keyVault.properties.vaultUri
