@description('Cosmos DB account name')
param accountName string = 'sql-${uniqueString(resourceGroup().id)}'

@description('The name for the SQL database')
param databaseName string

@description('Location for the Cosmos DB account.')
param location string = resourceGroup().location

param tags object = {}

var connectionStringSecretName = 'azure-cosmos-connection-string'

param privateEndpointSubnetId string
param privateEndpointName string
param managedIdentityPrincipalId string
param useManagedIdentityResourceAccess bool
param userPrincipalId string

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-08-15' = {
  name: toLower(accountName)
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    disableKeyBasedMetadataWriteAccess: false
    disableLocalAuth: false
    enableFreeTier: false
    enableAnalyticalStorage: false
    createMode: 'Default'
    databaseAccountOfferType: 'Standard'
    publicNetworkAccess: !empty(privateEndpointSubnetId) ? 'Disabled' : 'Enabled'
    networkAclBypass: 'AzureServices'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    cors: []
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-08-15' = {
  parent: cosmosAccount
  name: databaseName
  tags: tags
  properties: {
    resource: {
      id: databaseName
    }
    options: {}
  }
}

resource chatContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-08-15' = {
  parent: cosmosDatabase
  name: 'ChatTurn'
  tags: tags
  properties: {
    resource: {
      id: 'ChatTurn'
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
      partitionKey: {
        paths: [
          '/chatId'
        ]
        kind: 'Hash'
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
      conflictResolutionPolicy: {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
    }
    options: {}
  }
}

module privateEndpoint '../connectivity/private-endpoint.bicep' =
  if (!empty(privateEndpointSubnetId)) {
    name: '${accountName}-private-endpoint'
    params: {
      name: privateEndpointName
      groupIds: ['Sql']
      privateLinkServiceId: cosmosAccount.id
      subnetId: privateEndpointSubnetId
    }
  }

var roleDefinitions = loadJsonContent('../../data/roleDefinitions.json')

resource cosmosDbDataContributorRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-08-15' =
  if (useManagedIdentityResourceAccess) {
    name: guid(subscription().id, managedIdentityPrincipalId, roleDefinitions.cosmos.dataContributorRoleId, cosmosAccount.id)
    parent: cosmosAccount
    properties: {
      principalId: managedIdentityPrincipalId
      roleDefinitionId: '/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${cosmosDatabase.name}/sqlRoleDefinitions/${roleDefinitions.cosmos.dataContributorRoleId}'
      scope: cosmosAccount.id
    }
  }

resource cosmosDbUserAccessRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-08-15' =
  if (useManagedIdentityResourceAccess && userPrincipalId != '') {
    name: guid(subscription().id, userPrincipalId, roleDefinitions.cosmos.dataContributorRoleId, cosmosAccount.id)
    parent: cosmosAccount
    properties: {
      principalId: userPrincipalId
      roleDefinitionId: '/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${cosmosDatabase.name}/sqlRoleDefinitions/${roleDefinitions.cosmos.dataContributorRoleId}'
      scope: cosmosAccount.id
    }
  }

output endpoint string = cosmosAccount.properties.documentEndpoint
output id string = cosmosAccount.id
output name string = cosmosAccount.name
output keyVaultSecretName string = connectionStringSecretName
