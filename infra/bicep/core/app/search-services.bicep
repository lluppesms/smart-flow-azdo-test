param name string
param location string = resourceGroup().location
param tags object = {}

param sku object = {
  name: 'standard'
  //name: 'basic'
}

param networkRuleSet object = {
  bypass: 'AzurePortal'
  ipRules: []
}
param partitionCount int = 1
@allowed([
  'enabled'
  'disabled'
])
param publicNetworkAccess string
param replicaCount int = 1

param privateEndpointSubnetId string
param privateEndpointName string
param managedIdentityPrincipalId string
param useManagedIdentityResourceAccess bool

// --------------------------------------------------------------------------------------------------------------
var resourceGroupName = resourceGroup().name
var searchKeySecretName = 'search-key'

// --------------------------------------------------------------------------------------------------------------
resource search 'Microsoft.Search/searchServices@2023-11-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    networkRuleSet: networkRuleSet
    partitionCount: partitionCount
    publicNetworkAccess: publicNetworkAccess
    replicaCount: replicaCount
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
  }
  sku: sku
}

module privateEndpoint '../connectivity/private-endpoint.bicep' =
  if (!empty(privateEndpointSubnetId)) {
    name: '${name}-private-endpoint'
    params: {
      privateEndpointName: privateEndpointName
      groupIds: ['searchService']
      targetResourceId: search.id
      subnetId: privateEndpointSubnetId
    }
  }

var roleDefinitions = loadJsonContent('../../data/roleDefinitions.json')
 // See https://docs.microsoft.com/azure/role-based-access-control/role-assignments-template#new-service-principal
resource managedIdentitySearchIndexDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' =
  if (useManagedIdentityResourceAccess) {
    name: guid(subscription().id, managedIdentityPrincipalId, roleDefinitions.search.indexDataContributorRoleId)
    properties: {
      principalId: managedIdentityPrincipalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.search.indexDataContributorRoleId)
      principalType: 'ServicePrincipal'
    }
  }

resource managedIdentitySearchServiceContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' =
  if (useManagedIdentityResourceAccess) {
    name: guid(subscription().id, managedIdentityPrincipalId, roleDefinitions.search.serviceContributorRoleId)
    properties: {
      principalId: managedIdentityPrincipalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.search.serviceContributorRoleId)
      principalType: 'ServicePrincipal'
    }
  }

output id string = search.id
output endpoint string = 'https://${name}.search.windows.net/'
output name string = search.name
output resourceGroupName string = resourceGroupName
output searchKeySecretName string = searchKeySecretName
output searchServicePrincipalId string = search.identity.principalId
output keyVaultSecretName string = searchKeySecretName
