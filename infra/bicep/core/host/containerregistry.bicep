@description('Provide an existing name of an Azure Container Registry if using pre-existing one')
param existingRegistryName string = ''
@description('Provide resource group name for an existing Azure Container Registry if using pre-existing one')
param existing_ACR_ResourceGroupName string = ''
@description('Provide a globally unique name of your Azure Container Registry for a new server')
param newRegistryName string = ''
@description('Provide a tier of your Azure Container Registry.')
param acrSku string = ''
param location string = resourceGroup().location
param tags object = {}

var useExistingResource = !empty(existingRegistryName)

resource existingContainerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = if (useExistingResource) {
  name: existingRegistryName
  scope: resourceGroup(existing_ACR_ResourceGroupName)
}

resource newContainerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = if (!useExistingResource) {
  name: newRegistryName
  location: location
  tags: tags
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: false
  }
}

@description('Output the name for later use')
output name string = useExistingResource ? existingContainerRegistry.name : newContainerRegistry.name
@description('Output the login server property for later use')
output loginServer string = useExistingResource ? existingContainerRegistry.properties.loginServer : newContainerRegistry.properties.loginServer
