using 'main.bicep'

param location = 'eastus'
param keyVaultName = 'kv-test-ptzlabbicep1'

param tags = {
  environment: 'test'
  managed_by: 'bicep'
}
