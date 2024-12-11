param newEnvironmentName string = ''
param existingEnvironmentName string = ''
param location string = resourceGroup().location
param tags object = {}

// Reference Resource params
param logAnalyticsWorkspaceName string
param logAnalyticsRgName string
param appSubnetId string = ''

// --------------------------------------------------------------------------------------------------------------
var useExistingEnvironment = !empty(existingEnvironmentName)
var cleanAppEnvName = replace(newEnvironmentName, '_', '-')
var resourceGroupName = resourceGroup().name

// --------------------------------------------------------------------------------------------------------------
// Reference Resource
resource logAnalyticsResource 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
  scope: resourceGroup(logAnalyticsRgName)
}
var logAnalyticsKey = logAnalyticsResource.listKeys().primarySharedKey
var logAnalyticsCustomerId = logAnalyticsResource.properties.customerId

// App Environment
resource existingAppEnvironmentResource 'Microsoft.App/managedEnvironments@2024-03-01' existing = if (useExistingEnvironment) {
  name: existingEnvironmentName
}
resource newAppEnvironmentResource 'Microsoft.App/managedEnvironments@2024-03-01' = if (!useExistingEnvironment) {
  name: cleanAppEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalyticsKey
      }
    }
    vnetConfiguration: !empty(appSubnetId) ? {
      infrastructureSubnetId: appSubnetId
      internal: true
    } : {}
  }
}

output id string = useExistingEnvironment ? existingAppEnvironmentResource.id : newAppEnvironmentResource.id
output name string = useExistingEnvironment ? existingAppEnvironmentResource.name : newAppEnvironmentResource.name
output resourceGroupName string = resourceGroupName
