param keyVaultName string = ''

param openAiKeysecretName string
param openAiName string

param storageAccountName string
param storageAccountConnectionStringSecretName string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource account 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: openAiName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: storageAccountName
}

resource keyVaultSecretOpenAiKey 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: openAiKeysecretName
  properties: {
    value: account.listKeys().key1
  }
}

resource keyVaultSecretStorageAccountConnectionString 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: storageAccountConnectionStringSecretName
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
  }
  dependsOn: [
    storageAccount
  ]
}

output openAiKeySecretName string = keyVaultSecretOpenAiKey.name
output storageAccountConnectionStringSecretName string = keyVaultSecretStorageAccountConnectionString.name
