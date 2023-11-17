targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@allowed(['australiaeast', 'canadaeast', 'eastus', 'eastus2', 'francecentral', 'japaneast', 'northcentralus', 'swedencentral', 'switzerlandnorth', 'uksouth', ])
param location string

@description('Resource group name. If not provided, a default name will be generated.')
param resourceGroupName string

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : 'rg-enterprise-openai-${environmentName}'
  location: location
  tags: tags
}

// Generate a unique token to be used in naming resources.
// Remove linter suppression after using.
var resourceToken = toLower(uniqueString(subscription().id, resourceGroup.name, environmentName, location))

//Leave blank to use default naming
param openAiServiceName string = ''
param keyVaultName string = ''
param apimServiceName string = ''
param logAnalyticsName string = ''
param applicationInsightsName string = ''
param vnetName string = ''
param apimSubnetName string = ''
param apimNsgName string = ''
param privateEndpointSubnetName string = ''
param privateEndpointNsgName string = ''

var openAiSkuName = 'S0'
var chatGptDeploymentName = 'gpt-35'
var chatGptModelName = 'gpt-35-turbo'
var embeddingDeploymentName = 'embedding'
var embeddingModelName = 'text-embedding-ada-002'
var openaiApiKeySecretName = 'openai-apikey'

var storageAccountConnectionStringSecretName = 'storage-account-connection-string'

var openAiPrivateDnsZoneName = 'privatelink.openai.azure.com'
var keyVaultPrivateDnsZoneName = 'privatelink.vaultcore.azure.net'
var monitorPrivateDnsZoneName = 'privatelink.monitor.azure.com'
var eventHubPrivateDnsZoneName = 'privatelink.servicebus.windows.net'

var chargebackfunctionserviceName = 'chargebackfunctionapp'

var privateDnsZoneNames = [
  openAiPrivateDnsZoneName
  keyVaultPrivateDnsZoneName
  monitorPrivateDnsZoneName
  eventHubPrivateDnsZoneName 
]

module dnsDeployment './modules/networking/dns.bicep' = [for privateDnsZoneName in privateDnsZoneNames: {
  name: 'dns-deployment-${privateDnsZoneName}'
  scope: resourceGroup
  params: {
    name: privateDnsZoneName
  }
}]

module apimManagedIdentity './modules/security/managed-identity.bicep' ={
  name: 'apim-managed-identity'
  scope: resourceGroup
  params: {
    name: 'apim-mi-${resourceToken}'
    location: location
    tags: tags
  }
}

module functionAppManagedIdentity './modules/security/managed-identity.bicep' ={
  name: 'functionapp-managed-identity'
  scope: resourceGroup
  params: {
    name: 'func-mi-${resourceToken}'
    location: location
    tags: tags
  }
}

module vnet './modules/networking/vnet.bicep' = {
  name: 'vnet'
  scope: resourceGroup
  params: {
    name: !empty(vnetName) ? vnetName : 'vnet-${resourceToken}'
    apimSubnetName: !empty(apimSubnetName) ? apimSubnetName : 'snet-apim-${resourceToken}'
    apimNsgName: !empty(apimNsgName) ? apimNsgName : 'nsg-apim-${resourceToken}'
    privateEndpointSubnetName: !empty(privateEndpointSubnetName) ? privateEndpointSubnetName : 'snet-private-endpoint-${resourceToken}'
    privateEndpointNsgName: !empty(privateEndpointNsgName) ? privateEndpointNsgName : 'nsg-pe-${resourceToken}'
    functionAppSubnetName: 'snet-functionapp-${resourceToken}'
    functionAppNsgName: 'nsg-functionapp-${resourceToken}'
    location: location
    tags: tags
    privateDnsZoneNames: privateDnsZoneNames
  }
}

module openAi 'modules/openai/cognitiveservices.bicep' = {
  name: 'openai'
  scope: resourceGroup
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : 'cog-${resourceToken}'
    location: location
    tags: tags
    apimManagedIdentityName: apimManagedIdentity.outputs.managedIdentityName
    openAiPrivateEndpointName: 'cog-pe-${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    openAiDnsZoneName: openAiPrivateDnsZoneName
    sku: {
      name: openAiSkuName
    }
    deployments: [
      {
        name: chatGptDeploymentName
        model: {
          format: 'OpenAI'
          name: chatGptModelName
        }
        scaleSettings: {
          scaleType: 'Standard'
        }
      }
      {
        name: embeddingDeploymentName
        model: {
          format: 'OpenAI'
          name: embeddingModelName
          version: '2'
        }
        scaleSettings: {
          scaleType: 'Standard'
        }
      }
    ]
  }
}

module storageAccount './modules/functionapp/storageaccount.bicep' = {
  name: 'storage'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    storageAccountName: 'funcsa${resourceToken}'
    functionAppManagedIdentityName: functionAppManagedIdentity.outputs.managedIdentityName
  }
}


module keyVault './modules/security/key-vault.bicep' = {
  name: 'key-vault'  
  scope: resourceGroup
  params: {
    name: !empty(keyVaultName) ? keyVaultName : 'kv-${resourceToken}'
    location: location
    tags: tags
    keyVaultPrivateEndpointName: 'kv-private-endpoint-${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    apimManagedIdentityName: apimManagedIdentity.outputs.managedIdentityName
    functionAppManagedIdentityName: functionAppManagedIdentity.outputs.managedIdentityName
    keyVaultDnsZoneName: keyVaultPrivateDnsZoneName
  }
}

module keyVaultSecrets './modules/security/keyvault-secret.bicep' = {
  name: 'openai-keyvault-secret'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    openAiKeysecretName: openaiApiKeySecretName
    openAiName: openAi.outputs.openAiName
    storageAccountName: storageAccount.outputs.storageAccountName
    storageAccountConnectionStringSecretName: storageAccountConnectionStringSecretName    
  }
}


module eventhub './modules/eventhub/eventhub.bicep' = {
  name: 'eventhub'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    eventHubName: 'eh-${resourceToken}'
    eventHubPrivateEndpointName: 'eh-pe-${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    eventHubDnsZoneName: eventHubPrivateDnsZoneName
    apimManagedIdentityName: apimManagedIdentity.outputs.managedIdentityName
    functionAppManagedIdentityName: functionAppManagedIdentity.outputs.managedIdentityName
  }
}

module monitoring './modules/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : 'log-${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : 'appinsights-${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    applicationInsightsDnsZoneName: monitorPrivateDnsZoneName
    applicationInsightsPrivateEndpointName: 'appinsights-pe-${resourceToken}'
  }
}


module apim './modules/apim/apim.bicep' = {
  name: 'apim'
  scope: resourceGroup
  params: {
    apimName: !empty(apimServiceName) ? apimServiceName : 'apim-${resourceToken}'
    location: location
    tags: tags
    openaiKeyVaultSecretName: keyVaultSecrets.outputs.openAiKeySecretName
    keyVaultEndpoint: keyVault.outputs.keyVaultEndpoint
    openAiUri: openAi.outputs.openAiEndpointUri
    apimManagedIdentityName: apimManagedIdentity.outputs.managedIdentityName
    apimSubnetId: vnet.outputs.apimSubnetId
    eventHubNamespace: eventhub.outputs.eventHubNamespace
    eventHubName: eventhub.outputs.eventHubName
  }
}

module functionApp './modules/functionapp/functionapp.bicep' = {
  name: 'chargebackfunctionapp'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    functionAppName: 'chargebackfunctionapp-${resourceToken}'
    azdserviceName: chargebackfunctionserviceName   
    storageAccountName: storageAccount.outputs.storageAccountName
    functionAppIdentityName: functionAppManagedIdentity.outputs.managedIdentityName
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    eventHubNamespaceName: eventhub.outputs.eventHubNamespace
    eventHubConnectionString: eventhub.outputs.eventHubConnectionString
    eventHubName: eventhub.outputs.eventHubName   
    vnetName: vnet.outputs.vnetName
    functionAppSubnetId: vnet.outputs.functionAppSubnetId     
  }
}

output TENANT_ID string = subscription().tenantId
output AOI_DEPLOYMENTID string = chatGptDeploymentName
//output APIM_NAME string = apim.outputs.apimName
//output APIM_AOI_PATH string = apim.outputs.apimOpenaiApiPath

