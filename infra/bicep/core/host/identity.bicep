param registryName string
param userAssignedIdentityName string
param location string = resourceGroup().location

resource registry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: registryName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: userAssignedIdentityName
  location: location
}

var acrPullDefinitionId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var acrPullCaName = guid(registry.id, userAssignedIdentityName, acrPullDefinitionId)

// Assign the 'acrpull' role to the managed identity of the Container App
module roleAssignment '../iam/roleassignment.bicep' = {
  name: '${userAssignedIdentityName}-roleAssignment-acrpull'
  params: {
    resourceId: registry.id
    description: 'acrpull'
    roledescription: 'acrpull'
    name: acrPullCaName
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', acrPullDefinitionId)
    registryName: registry.name
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}


output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output managedIdentityClientlId string = managedIdentity.properties.clientId
output managedIdentityId string = managedIdentity.id
output managedIdentityName string = managedIdentity.name
