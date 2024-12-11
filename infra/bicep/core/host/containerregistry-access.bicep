// Assign the 'acrpull' role in the container registry to the supplied identity
param registryName string
param identityPrincipalId string

var roleDefinitions = loadJsonContent('../../data/roleDefinitions.json')

var roleAssignmentName = guid(registryName, identityPrincipalId, 'acrPull')

resource registry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: registryName
}

resource existingRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: roleAssignmentName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (existingRoleAssignment.id == null) {
  name: roleAssignmentName
  properties: {
    principalId: identityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitions.containerregistry.acrPullRoleId)
  }
}

output resourceId string = registry.id
output roleAssignmentId string = (existingRoleAssignment.id == null) ? roleAssignment.id : existingRoleAssignment.id
