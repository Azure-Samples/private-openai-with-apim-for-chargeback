param eventHubName string
param location string = resourceGroup().location
param tags object = {}
param eventHubSku string = 'Standard'

param eventHubPrivateEndpointName string
param vNetName string
param privateEndpointSubnetName string
param eventHubDnsZoneName string
param apimManagedIdentityName string
param functionAppManagedIdentityName string

//https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#azure-event-hubs-data-sender
var eventHubDataSenderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2b629674-e913-4c01-ae53-ef4638d8f975')

//https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference?tabs=eventhubs&pivots=programming-language-csharp#grant-permission-to-the-identity
//https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#azure-event-hubs-data-receiver
var eventHubDataReceiverRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a638d3c7-ab3a-418d-83e6-5f17a39d4fde')
// https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#azure-event-hubs-data-owner
var eventHubDataOwnwerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f526a384-b230-433a-b45c-95f59c4a2dec')


resource apimManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: apimManagedIdentityName
}

resource functionAppmanagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: functionAppManagedIdentityName
}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2022-10-01-preview' = {
  name: !empty(eventHubName) ? '${eventHubName}-ns' : 'eventhub-${uniqueString(resourceGroup().id)}-ns'
  location: location
  tags: union(tags, { 'azd-service-name': eventHubName })
  sku: {
    name: eventHubSku
    tier: eventHubSku
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
    publicNetworkAccess: 'Disabled'
  }
  
}

//Assign EventHub Data Sender Role to APIM Managed Identity
resource eventHubDataSenderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(eventHub.id, apimManagedIdentity.name, eventHubDataSenderRoleId)
  properties: {
    principalId: apimManagedIdentity.properties.principalId
    roleDefinitionId: eventHubDataSenderRoleId
  }
  scope: eventHubNamespace
}

//Assign EventHub Data Owner Role to Function App Managed Identity
resource eventHubDataOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(eventHub.id, functionAppmanagedIdentity.name, eventHubDataOwnwerRoleId)
  properties: {
    principalId: functionAppmanagedIdentity.properties.principalId
    roleDefinitionId: eventHubDataOwnwerRoleId
  }
  scope: eventHubNamespace
}

//Assign EventHub Data Receiver Role to Function App Managed Identity
resource eventHubDataReceiverRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(eventHub.id, functionAppmanagedIdentity.name, eventHubDataReceiverRoleId)
  properties: {
    principalId: functionAppmanagedIdentity.properties.principalId
    roleDefinitionId: eventHubDataReceiverRoleId
  }
  scope: eventHubNamespace
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2022-01-01-preview' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    messageRetentionInDays: 7
    partitionCount: 1
  }
}

resource eventHubListenSendRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2021-01-01-preview' = {
  parent: eventHub
  name: 'ListenSend'
  properties: {
    rights: [
      'Listen'
      'Send'
    ]
  }  
}

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${eventHubName}-privateEndpoint'
  params: {
    groupIds: [
      'namespace'
    ]
    dnsZoneName: eventHubDnsZoneName
    name: eventHubPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: eventHubNamespace.id
    vNetName: vNetName
    location: location
  }
}

//output eventHubNamespace
output eventHubNamespace string = eventHubNamespace.name
//output eventHubName
output eventHubName string = eventHub.name

output eventHubConnectionString string = eventHubListenSendRule.listkeys().primaryConnectionString


