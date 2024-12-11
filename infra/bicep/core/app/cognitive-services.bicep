param existingCogServicesName string
param existingCogServicesResourceGroupName string
param name string
param location string = resourceGroup().location
param tags object = {}
//param deployments array = []
param kind string = 'OpenAI'
param publicNetworkAccess string
param sku object = {
  name: 'S0'
}
param privateEndpointSubnetId string
param privateEndpointName string

param searchServicePrincipalId string
param useManagedIdentityResourceAccess bool

param textEmbedding object
param chatGpt_Standard object
param chatGpt_Premium object

// --------------------------------------------------------------------------------------------------------------
var resourceGroupName = resourceGroup().name
var cognitiveServicesKeySecretName = 'cognitive-services-key'
var deployments = [
    {
      name: textEmbedding.DeploymentName
      model: {
        format: 'OpenAI'
        name: textEmbedding.ModelName
        version: textEmbedding.ModelVersion
      }
      sku: {
        name: 'Standard'
        capacity: textEmbedding.DeploymentCapacity
      }
    }
    {
      name: chatGpt_Standard.DeploymentName
      model: {
        format: 'OpenAI'
        name: chatGpt_Standard.ModelName
        version: chatGpt_Standard.ModelVersion
      }
      sku: {
        name: 'Standard'
        capacity: chatGpt_Standard.DeploymentCapacity
      }
    }
    {
      name: chatGpt_Premium.DeploymentName
      model: {
        format: 'OpenAI'
        name: chatGpt_Premium.ModelName
        version: chatGpt_Premium.ModelVersion
      }
      sku: {
        name: 'Standard'
        capacity: chatGpt_Premium.DeploymentCapacity
      }
    }
  ]

// --------------------------------------------------------------------------------------------------------------
resource existingAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' existing =
  if (!empty(existingCogServicesName)) {
    scope: resourceGroup(existingCogServicesResourceGroupName)
    name: existingCogServicesName
  }

resource account 'Microsoft.CognitiveServices/accounts@2023-05-01' =
  if (empty(existingCogServicesName)) {
    name: name
    location: location
    tags: tags
    kind: kind
    properties: {
      publicNetworkAccess: publicNetworkAccess
      networkAcls: {
        defaultAction: !empty(privateEndpointSubnetId) ? 'Deny' : 'Allow'
      }
      customSubDomainName: name
    }
    sku: sku
  }

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [
  for deployment in deployments: if (empty(existingCogServicesName)) {
    parent: account
    name: deployment.name
    properties: {
      model: deployment.model
      // // use the policy in the deployment if it exists, otherwise default to null
      // raiPolicyName: deployment.?raiPolicyName ?? null
    }
    // use the sku in the deployment if it exists, otherwise default to standard
    sku: deployment.?sku ?? {
      name: 'Standard'
      capacity: 20
    }
  }
]

var roleDefinitions = loadJsonContent('../../data/roleDefinitions.json')
// this is not quite right yet...!
// Search service needs "Cognitive Services OpenAI Contributor" role to create indexes using the text-embedding model
// See https://docs.microsoft.com/azure/role-based-access-control/role-assignments-template#new-service-principal
resource managedIdentitySearchServiceContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' =
  if (useManagedIdentityResourceAccess) {
    name: guid(subscription().id, searchServicePrincipalId, roleDefinitions.openai.cognitiveServicesOpenAIContributorRoleId)
    properties: {
      principalId: searchServicePrincipalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.openai.cognitiveServicesOpenAIContributorRoleId)
      principalType: 'ServicePrincipal'
    }
  }

module privateEndpoint '../connectivity/private-endpoint.bicep' =
  if (!empty(existingCogServicesName) && !empty(privateEndpointSubnetId)) {
    name: '${name}-private-endpoint'
    params: {
      privateEndpointName: privateEndpointName
      groupIds: ['account']
      targetResourceId: account.id
      subnetId: privateEndpointSubnetId
    }
  }

output endpoint string = !empty(existingCogServicesName)
  ? existingAccount.properties.endpoint
  : account.properties.endpoint
output id string = !empty(existingCogServicesName) ? existingAccount.id : account.id
output name string = !empty(existingCogServicesName) ? existingAccount.name : account.name
output resourceGroupName string = !empty(existingCogServicesName) ? existingCogServicesResourceGroupName : resourceGroupName
output keyVaultSecretName string = cognitiveServicesKeySecretName
