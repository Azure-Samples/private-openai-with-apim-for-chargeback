param logAnalyticsName string
param applicationInsightsName string
param location string = resourceGroup().location
param tags object = {}
param vNetName string
param privateEndpointSubnetName string
param applicationInsightsDnsZoneName string
param applicationInsightsPrivateEndpointName string

var privateLinkScopeName = 'private-link-scope'

resource privateLinkScope 'microsoft.insights/privateLinkScopes@2021-07-01-preview' = {
  name: privateLinkScopeName
  location: 'global'
  properties: {
    accessModeSettings: {
      ingestionAccessMode: 'Open'
      queryAccessMode: 'Open'
    }
  }
}

module logAnalytics 'loganalytics.bicep' = {
  name: 'log-analytics'
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
    privateLinkScopeName: privateLinkScopeName
  }
}

module applicationInsights 'applicationinsights.bicep' = {
  name: 'application-insights'
  params: {
    name: applicationInsightsName
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    privateLinkScopeName: privateLinkScopeName
    vNetName: vNetName
    privateEndpointSubnetName: privateEndpointSubnetName
    dnsZoneName: applicationInsightsDnsZoneName
    privateEndpointName: applicationInsightsPrivateEndpointName
  }
}

output applicationInsightsName string = applicationInsights.outputs.applicationInsightsName
output logAnalyticsWorkspaceId string = logAnalytics.outputs.id
output logAnalyticsWorkspaceName string = logAnalytics.outputs.name
