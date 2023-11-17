param apimName string
param location string = resourceGroup().location
param tags object = {}

@minLength(1)
param publisherEmail string = 'noreply@microsoft.com'

@minLength(1)
param publisherName string = 'n/a'
param sku string = 'Developer'
param skuCount int = 1
param openAiUri string
param openaiKeyVaultSecretName string
param keyVaultEndpoint string
param apimManagedIdentityName string
param apimSubnetId string
param eventHubNamespace string
param eventHubName string

var openAiApiKeyNamedValue = 'openai-apikey'
var openAiApiBackendId = 'openai-backend'
var apimloggerName = 'OpenAILogger'
var apimManagedIdentityClientIdNamedValue = 'apim-mi-clientId'


resource apimManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: apimManagedIdentityName
}

resource apimService 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: apimName
  location: location
  tags: union(tags, { 'azd-service-name': apimName })
  sku: {
    name: sku
    capacity: (sku == 'Consumption') ? 0 : ((sku == 'Developer') ? 1 : skuCount)
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${apimManagedIdentity.id}': {}
    }
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: 'External'
    virtualNetworkConfiguration: {
      subnetResourceId: apimSubnetId
    }
    // Custom properties are not supported for Consumption SKU
    customProperties: sku == 'Consumption' ? {} : {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_GCM_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
    }
  }
}

resource apimOpenaiApi 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  name: 'azure-openai-service-api'
  parent: apimService
  properties: {
    path: 'openai'
    apiRevision: '1'
    displayName: 'Azure OpenAI Service API'
    subscriptionRequired: true
    format: 'openapi+json'
    value: loadJsonContent('./openapi/openai-openapiv3.json')
    protocols: [
      'https'
    ]
  }
}

//Product for OpenAI API
resource openAiProduct 'Microsoft.ApiManagement/service/products@2023-03-01-preview' = {
  parent: apimService
  name: 'OpenAI'
  properties: {
    displayName: 'OpenAI'
    description: 'OpenAI API Product'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}

//Link OpenAI API to Product
resource openAiProductLink 'Microsoft.ApiManagement/service/products/apiLinks@2023-03-01-preview' = {
  name: 'openai-product-apilink'
  parent: openAiProduct
  properties: {
    apiId: apimOpenaiApi.id
  }
}
// Add Subscription fpr OpenAI Product
resource openAiSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-03-01-preview' = {
  name: 'openai-subscription'
  parent: apimService
  properties: {
    scope: openAiProduct.id
    displayName: 'Open Ai Subscription'
    state: 'active'
    allowTracing: false
  }
}


resource openAiBackend 'Microsoft.ApiManagement/service/backends@2021-08-01' = {
  name: openAiApiBackendId
  parent: apimService
  properties: {
    description: openAiApiBackendId
    url: openAiUri
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

resource apimOpenaiApiKeyNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = {
  name: openAiApiKeyNamedValue
  parent: apimService
  properties: {
    displayName: openAiApiKeyNamedValue
    secret: true
    keyVault:{
      secretIdentifier: '${keyVaultEndpoint}secrets/${openaiKeyVaultSecretName}'
      identityClientId: apimManagedIdentity.properties.clientId
    }
  }  
}

resource apimManagedIdClientIdNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = {
  name: apimManagedIdentityClientIdNamedValue
  parent: apimService
  properties: {
    displayName: apimManagedIdentityClientIdNamedValue
    secret: true
    value: apimManagedIdentity.properties.clientId
  }
}

resource openaiApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2022-08-01' = {
  name: 'policy'
  parent: apimOpenaiApi
  properties: {
    value: loadTextContent('./policies/api_eventhub_logging_policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    openAiBackend
  ]
}

//Add Policy to Chat Completions Endpoint
resource apiOperationChatCompletions 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' existing = {
  name: 'ChatCompletions_Create'
  parent: apimOpenaiApi
}

resource chatCompletionsCreatePolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2022-08-01' = {
  name: 'policy'
  parent: apiOperationChatCompletions
  properties: {
    value: loadTextContent('./policies/api_chat_completions_operation_policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    apimManagedIdentity
    apimManagedIdClientIdNamedValue
  ]
  
}

//Add Policy to Completions Endpoint
resource apiOperationCompletions 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' existing = {
  name: 'Completions_Create'
  parent: apimOpenaiApi
}

resource completionsCreatePolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2022-08-01' = {
  name: 'policy'
  parent: apiOperationCompletions
  properties: {
    value: loadTextContent('./policies/api_completions_operation_policy.xml')
    format: 'rawxml'
  }
}


//Event Hub Logger
resource eventHubLoggerWithUserAssignedIdentity 'Microsoft.ApiManagement/service/loggers@2022-04-01-preview' = {
  name: apimloggerName
  parent: apimService
  properties: {
    loggerType: 'azureEventHub'
    description: 'Event hub logger with user-assigned managed identity'
    credentials: {
      endpointAddress: '${eventHubNamespace}.servicebus.windows.net'
      //use a pre-existing named value as apim logger creates a new named value on every deployment
      //https://github.com/Azure/azure-powershell/issues/12228
      identityClientId: '{{ apim-mi-clientId }}' 
      name: eventHubName
    }
  }
  dependsOn: [
    apimManagedIdentity
    apimManagedIdClientIdNamedValue
  ]
}

output apimName string = apimService.name
output apimOpenaiApiPath string = apimOpenaiApi.properties.path
