// --------------------------------------------------------------------------------------------------------------
// Main bicep file that deploys EVERYTHING for the application, with optional parameters for existing resources.
// --------------------------------------------------------------------------------------------------------------
// You can test it with these commands:
//   Most basic of test commands:
//     az deployment sub create -n manual --location EastUS --template-file 'main-complete.bicep' --parameters applicationName=myApp environmentName=dev
//   Deploy with existing resources specified in a parameter file:
//     az deployment sub create -n manual --location EastUS --template-file 'main-complete.bicep' --parameters main-complete-existing.bicepparam
// --------------------------------------------------------------------------------------------------------------
targetScope = 'subscription'

// you can supply a full application name, or you don't it will append resource tokens to a default suffix
@description('Full Application Name (supply this or use default of prefix+token)')
param applicationName string = ''
@description('If you skip Application Name, this prefix will be combined with a token to create the applicationName')
param applicationPrefix string = 'ai_doc'

@description('The environment code (i.e. dev, qa, prod)')
param environmentName string = 'dev'
@description('Environment name used by the azd command (optional)')
param azdEnvName string = ''

@description('Primary location for all resources')
param location string = 'westus'

@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('Should internal resources use managed identity for access?')
param useManagedIdentityResourceAccess bool = true

// --------------------------------------------------------------------------------------------------------------
// Existing resource groups?
// --------------------------------------------------------------------------------------------------------------
@description('If you provide this the application resources will be created here instead of creating a new RG')
param existingRG_App_Name string = ''
@description('If you provide this the network resources will be created here instead of creating a new RG')
param existingRG_Connectivity_Name string = ''

// --------------------------------------------------------------------------------------------------------------
// Existing networks?
// --------------------------------------------------------------------------------------------------------------
@description('If you provide this is will be used instead of creating a new VNET')
param existingVnetName string = ''
@description('If you provide this is will be used instead of creating a new VNET')
param existingVnetPrefix string = '10.2.0.0/16'
@description('If new VNET, this is the Subnet name for the private endpoints')
param subnet1Name string = 'snet-prv-endpoint'
@description('If new VNET, this is the Subnet addresses for the private endpoints, i.e. 10.2.0.0/26') //Provided subnet must have a size of at least /23
param subnet1Prefix string = '10.2.0.0/23'
@description('If new VNET, this is the Subnet name for the application')
param existingAppSubnetName string = ''
@description('If new VNET, this is the Subnet addresses for the application, i.e. 10.2.2.0/23') // Provided subnet must have a size of at least /23
param subnet2Prefix string = '10.2.2.0/23'

// --------------------------------------------------------------------------------------------------------------
// Existing container registry?
// --------------------------------------------------------------------------------------------------------------
@description('If you provide this is will be used instead of creating a new Registry')
param existing_ACR_Name string = ''
@description('For a new Registry, this is the Registry SKU')
param ACR_Sku string = 'Basic'

// --------------------------------------------------------------------------------------------------------------
// Existing monitoring?
// --------------------------------------------------------------------------------------------------------------
@description('If you provide this is will be used instead of creating a new Workspace')
param existing_LogAnalytics_Name string = ''
@description('If you provide this is will be used instead of creating a new App Insights')
param existing_AppInsights_Name string = ''

// --------------------------------------------------------------------------------------------------------------
// Existing Container App Environment?
// --------------------------------------------------------------------------------------------------------------
@description('If you provide this is will be used instead of creating a new Container App Environment')
param existing_managedAppEnvName string = ''

// --------------------------------------------------------------------------------------------------------------
// Existing OpenAI resources?
// --------------------------------------------------------------------------------------------------------------
@description('Name of an existing Cognitive Services account to use')
param existingCogServicesName string = ''
@description('Name of ResourceGroup for an existing Cognitive Services account to use')
param existingCogServicesResourceGroup string = ''

@description('Text embedding deployment name. Default: text-embedding')
param aOAIChatGpt_TextEmbedding_DeploymentName string = 'text-embedding'
@description('Text embedding model. Default: text-embedding-ada-002')
param aOAIChatGpt_TextEmbedding_ModelName string = 'text-embedding-ada-002'
@description('Text embedding version: Default 2')
param aOAIChatGpt_TextEmbedding_ModelVersion string = '2'
@description('Text embedding deployment capacity. Default: 10')
param aOAIChatGpt_TextEmbedding_DeploymentCapacity int = 30

@description('Standard chat GPT deployment name. Default: gpt-35-turbo')
param aOAIChatGpt_Standard_DeploymentName string = 'gpt-35-turbo'
@description('Standard chat GPT model. Default: gpt-35-turbo')
@allowed(['gpt-35-turbo', 'gpt-4', 'gpt-35-turbo-16k', 'gpt-4-16k', 'gpt-4o'])
param aOAIChatGpt_Standard_ModelName string = 'gpt-35-turbo'
@description('Standard chat GPT version: Default 0125')
param aOAIChatGpt_Standard_ModelVersion string = '0125'
@description('Standard chat GPT deployment capacity. Default: 10')
param aOAIChatGpt_Standard_DeploymentCapacity int = 10

@description('Premium chat GPT deployment name. Default: gpt-4o')
param aOAIChatGpt_Premium_DeploymentName string = 'gpt-4o'
@description('Premium chat GPT model. Default: gpt-4o')
@allowed(['gpt-35-turbo', 'gpt-4', 'gpt-35-turbo-16k', 'gpt-4-16k', 'gpt-4o'])
param aOAIChatGpt_Premium_ModelName string = 'gpt-4o'
@description('Premium chat GPT version: Default 2024-05-13')
param aOAIChatGpt_Premium_ModelVersion string = '2024-05-13'
@description('Premium chat GPT deployment capacity. Default: 10')
param aOAIChatGpt_Premium_DeploymentCapacity int = 10

// --------------------------------------------------------------------------------------------------------------
// Deploy Cosmos Database?
// --------------------------------------------------------------------------------------------------------------
@description('Should we deploy CosmosDB?')
param deploy_Cosmos bool = true

// --------------------------------------------------------------------------------------------------------------
// Make all names unique?
// --------------------------------------------------------------------------------------------------------------
@description('Set this if you want to append all the resource names with a unique token')
param append_Resource_Token bool = false

// --------------------------------------------------------------------------------------------------------------
// A variable masquerading as a parameter to allow for dynamic value assignment in Bicep
// --------------------------------------------------------------------------------------------------------------
param runDateTime string = utcNow()

// --------------------------------------------------------------------------------------------------------------
// Variables
// --------------------------------------------------------------------------------------------------------------
var resourceToken = toLower(uniqueString(subscription().id, location))

// if user supplied a full application name, use that, otherwise use default prefix and a unique token
var appName = applicationName != '' ? applicationName : '${applicationPrefix}_${resourceToken}'

var deploymentSuffix = '-${runDateTime}'

// if this bicep was called from AZD, then it needs this tag added to the resource group (at a minimum) to deploy successfully...
var azdTag = azdEnvName != '' ? { 'azd-env-name': azdEnvName } : { }

var commonTags = {
    LastDeployed: runDateTime
    Application: appName
    ApplicationName: applicationName
    Environment: environmentName
}
var tags = union(commonTags, azdTag)

var resourceAbbreviations = loadJsonContent('./data/abbreviation.json')
var rg_App_Name = !empty(existingRG_App_Name) ? existingRG_App_Name : '${resourceAbbreviations.resourcesResourceGroups}_${appName}_${environmentName}'
var rg_Connectivity_Name = !empty(existingRG_Connectivity_Name) ? existingRG_Connectivity_Name : rg_App_Name

var createConnectivityRG = (rg_App_Name != rg_Connectivity_Name)

var existingCogServicesRG = existingCogServicesResourceGroup == '' ? rg_App_Name : existingCogServicesResourceGroup

// --------------------------------------------------------------------------------------------------------------
// -- Create Resource Groups ------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
resource rg_app 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: rg_App_Name
  location: location
  tags: tags
}
resource rg_connectivity_new 'Microsoft.Resources/resourceGroups@2024-07-01' = if (createConnectivityRG) {
  name: rg_Connectivity_Name
  location: location
  tags: tags
}

// --------------------------------------------------------------------------------------------------------------
// -- Generate Resource Names -----------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
module resourceNames 'resourcenames.bicep' = {
  name: 'names${deploymentSuffix}'
  scope:  resourceGroup(rg_app.name)
  params: {
    applicationName: appName
    environmentName: environmentName
    resourceToken: append_Resource_Token ? resourceToken : ''
  }
}

// --------------------------------------------------------------------------------------------------------------
// -- VNET ------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
module vnet './core/connectivity/vnet.bicep' = {
  name: 'vnet${deploymentSuffix}'
  // scope: createConnectivityRG ? resourceGroup(rg_connectivity_new.name) : resourceGroup(rg_app.name)
  scope: resourceGroup(rg_app.name)
  params: {
    existingVirtualNetworkName: existingVnetName
    newVirtualNetworkName: resourceNames.outputs.vnet_Name
    vnetAddressPrefix: existingVnetPrefix
    subnet1Name: subnet1Name
    subnet1Prefix: subnet1Prefix
    subnet2Name: !empty(existingAppSubnetName) ? existingAppSubnetName : resourceNames.outputs.vnetAppSubnetName
    subnet2Prefix: subnet2Prefix
  }
}

// --------------------------------------------------------------------------------------------------------------
// -- Container Registry ----------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
module containerRegistry './core/host/containerregistry.bicep' =  {
  name: 'cnt-reg${deploymentSuffix}'
  scope: resourceGroup(rg_app.name)
  params: {
    existingRegistryName: existing_ACR_Name
    newRegistryName: resourceNames.outputs.ACR_Name
    location: location
    acrSku: ACR_Sku
    tags: tags
  }
}

// --------------------------------------------------------------------------------------------------------------
// -- Log Analytics Workspace and App Insights ------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
module logAnalytics './core/monitor/loganalytics.bicep' = {
  name: 'law${deploymentSuffix}'
  scope: resourceGroup(rg_app.name)
  params: {
    existingLogAnalyticsName: existing_LogAnalytics_Name
    newLogAnalyticsName: resourceNames.outputs.logAnalyticsWorkspaceName
    existingApplicationInsightsName: existing_AppInsights_Name
    newApplicationInsightsName: resourceNames.outputs.appInsightsName
    location: location
    tags: tags
  }
}

// --------------------------------------------------------------------------------------------------------------
// -- Key Vault Resources ---------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------

module identity './core/host/identity.bicep' = {
  name: 'userassigned-identity-${deploymentSuffix}'
  scope: rg_app
  params: {
    registryName: containerRegistry.name
    userAssignedIdentityName: 'userassigned-identity-${appName}'
  }
}

module keyVault './core/security/keyvault.bicep' = {
  name: 'keyvault${deploymentSuffix}'
  scope: resourceGroup(rg_app.name)
  params: {
    location: location
    commonTags: tags
    keyVaultName: resourceNames.outputs.keyVaultName
    keyVaultOwnerUserId: principalId
    adminUserObjectIds: [ identity.outputs.managedIdentityPrincipalId ]
    publicNetworkAccess: 'Enabled'
  }
}

// Future use: get list of secrets from vault so you don't recreate duplicates every time this runs
// module keyVaultSecretList './core/security/keyvaultlistsecretnames.bicep' = {
//   name: 'keyVault-Secret-List-Names${deploymentSuffix}'
//   scope: resourceGroup(rg_app.name)
//   params: {
//     keyVaultName: keyVault.outputs.name
//     location: location
//     userManagedIdentityId: keyVault.outputs.userManagedIdentityId
//   }
// // }

// module cosmosSecret './core/security/keyvault-cosmos-secret.bicep' = {
//   name: 'cosmos-secret${deploymentSuffix}'
//   scope: resourceGroup(rg_app.name)
//   params: {
//     keyVaultName: keyVault.outputs.name
//     cosmosAccountName: cosmos.outputs.name
//     secretName: cosmos.outputs.keyVaultSecretName
//   }
// }

// module openAISecret './core/security/keyvault-cognitive-secret.bicep' = if (empty(existingCogServicesName)) {
//   name: 'openai-secret${deploymentSuffix}'
//   scope: resourceGroup(rg_app.name)
//   params: {
//     keyVaultName: keyVault.outputs.name
//     cognitiveServiceName: openAI.outputs.name
//     cognitiveServiceResourceGroup: openAI.outputs.resourceGroupName
//     name: openAI.outputs.keyVaultSecretName
//   }
// }
// module searchSecret './core/security/keyvault-search-secret.bicep' = {
//   name: 'search-secret${deploymentSuffix}'
//   scope: resourceGroup(rg_app.name)
//   params: {
//     keyVaultName: keyVault.outputs.name
//     searchServiceName: searchService.outputs.name
//     searchServiceResourceGroup: searchService.outputs.resourceGroupName
//     name: searchService.outputs.keyVaultSecretName
//   }
// }

// // --------------------------------------------------------------------------------------------------------------
// // -- Cosmos Resources ------------------------------------------------------------------------------------------
// // --------------------------------------------------------------------------------------------------------------
// module cosmos './core/app/cosmosdb.bicep' = if (deploy_Cosmos) {
//   name: 'cosmos${deploymentSuffix}'
//   scope: resourceGroup(rg_app.name)
//   params: {
//     accountName: resourceNames.outputs.cosmosName
//     databaseName: 'ChatHistory'
//     location: location
//     tags: tags
//     privateEndpointSubnetId: ''
//     privateEndpointName: ''
//     useManagedIdentityResourceAccess: useManagedIdentityResourceAccess
//     managedIdentityPrincipalId: identity.outputs.managedIdentityPrincipalId
//     userPrincipalId: principalId
//   }
// }

// // --------------------------------------------------------------------------------------------------------------
// // -- Cognitive Services Resources ------------------------------------------------------------------------------
// // --------------------------------------------------------------------------------------------------------------
// module searchService './core/app/search-services.bicep' = {
//   name: 'search${deploymentSuffix}'
//   scope: resourceGroup(rg_app.name)
//   params: {
//     location: location
//     name: resourceNames.outputs.searchServiceName
//     publicNetworkAccess: 'enabled'
//     privateEndpointSubnetId: ''
//     privateEndpointName: ''
//     useManagedIdentityResourceAccess: useManagedIdentityResourceAccess
//     managedIdentityPrincipalId: identity.outputs.managedIdentityPrincipalId
//   }
// }

// // --------------------------------------------------------------------------------------------------------------
// // -- Azure OpenAI Resources ------------------------------------------------------------------------------------
// // --------------------------------------------------------------------------------------------------------------
// module openAI './core/app/cognitive-services.bicep' = {
//   name: 'openai${deploymentSuffix}'
//   dependsOn: [searchService]
//   scope: resourceGroup(rg_app.name)
//   params: {
//     existingCogServicesName: existingCogServicesName
//     existingCogServicesResourceGroup: existingCogServicesRG
//     name: resourceNames.outputs.cogServiceName
//     location: 'westus' // location
//     tags: tags
//     useManagedIdentityResourceAccess: useManagedIdentityResourceAccess
//     searchServicePrincipalId: searchService.outputs.searchServicePrincipalId
//     textEmbedding: {
//       DeploymentName: aOAIChatGpt_TextEmbedding_DeploymentName
//       ModelName: aOAIChatGpt_TextEmbedding_ModelName
//       ModelVersion: aOAIChatGpt_TextEmbedding_ModelVersion
//       DeploymentCapacity: aOAIChatGpt_TextEmbedding_DeploymentCapacity
//     }
//     chatGpt_Standard: {
//       DeploymentName: aOAIChatGpt_Standard_DeploymentName
//       ModelName: aOAIChatGpt_Standard_ModelName
//       ModelVersion: aOAIChatGpt_Standard_ModelVersion
//       DeploymentCapacity: aOAIChatGpt_Standard_DeploymentCapacity
//     }
//     chatGpt_Premium: {
//       DeploymentName: aOAIChatGpt_Premium_DeploymentName
//       ModelName: aOAIChatGpt_Premium_ModelName
//       ModelVersion: aOAIChatGpt_Premium_ModelVersion
//       DeploymentCapacity: aOAIChatGpt_Premium_DeploymentCapacity
//     }
//     publicNetworkAccess: 'Enabled' // virtualNetworkName != '' 'Disabled' : 'Enabled'
//     privateEndpointSubnetId: '' // virtualNetworkName != '' virtualNetwork.outputs.privateEndpointSubnetId: ''
//     privateEndpointName: '' // virtualNetworkName != '' '${abbrs.networkPrivateLinkServices}${abbrs.cognitiveServicesAccounts}${resourceToken}': ''
//   }
// }

// // --------------------------------------------------------------------------------------------------------------
// // -- Container App Environment ---------------------------------------------------------------------------------
// // --------------------------------------------------------------------------------------------------------------
// module managedEnvironment './core/host/managedEnvironment.bicep' = {
//   name: 'ca-env${deploymentSuffix}'
//   scope: resourceGroup(rg_app.name)
//   params: {
//     existingEnvironmentName: existing_managedAppEnvName
//     newEnvironmentName: resourceNames.outputs.caManagedEnvName
//     location: location
//     logAnalyticsWorkspaceName: logAnalytics.outputs.logAnalyticsWorkspaceName
//     logAnalyticsRgName: rg_app.name
//     appSubnetId: vnet.outputs.subnet1ResourceId
//     tags: tags
//   }
// }

// module containerAppUI './core/host/containerappstub.bicep' = {
//   name: 'ca-ui-stub${deploymentSuffix}'
//   scope: resourceGroup(rg_app.name)
//   params: {
//       appName: resourceNames.outputs.containerAppUIName
//       managedEnvironmentName: managedEnvironment.outputs.name
//       managedEnvironmentRg: managedEnvironment.outputs.resourceGroupName
//       registryName: resourceNames.outputs.ACR_Name
//       userAssignedIdentityName: identity.outputs.managedIdentityName
//       targetPort: 8080
//       location: location
//       tags: union(tags, { 'azd-service-name': 'ui' })
//     }
//   dependsOn: [
//     containerRegistry
//     managedEnvironment
//   ]
//   }

// module containerAppAPI './core/host/containerappstub.bicep' = {
//   name: 'ca-api-stub${deploymentSuffix}'
//   scope: resourceGroup(rg_app.name)
//   params: {
//       appName: resourceNames.outputs.containerAppAPIName
//       managedEnvironmentName: managedEnvironment.outputs.name
//       managedEnvironmentRg: managedEnvironment.outputs.resourceGroupName
//       registryName: resourceNames.outputs.ACR_Name
//       targetPort: 8080
//       userAssignedIdentityName: identity.outputs.managedIdentityName
//       location: location
//       tags: union(tags, { 'azd-service-name': 'api' })
//     }
//   }

// --------------------------------------------------------------------------------------------------------------
// -- Outputs ---------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------------
output RESOURCE_TOKEN string = resourceToken
output VNET_CORE_ID string = vnet.outputs.vnetResourceId
output VNET_CORE_NAME string = vnet.outputs.vnetName
output VNET_CORE_PREFIX string = vnet.outputs.vnetAddressPrefix
output AZURE_RESOURCE_GROUP string = rg_app.name
output AZURE_CONNECTIVITY_RG_NAME string = createConnectivityRG ? rg_connectivity_new.name : rg_app.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name
// output MANAGED_ENVIRONMENT_NAME string = managedEnvironment.outputs.name
// output MANAGED_ENVIRONMENT_ID string = managedEnvironment.outputs.id
// output UI_CONTAINER_APP_NAME string = containerAppUI.outputs.name
// output UI_CONTAINER_APP_FQDN string = containerAppUI.outputs.fqdn
// output API_CONTAINER_APP_NAME string = containerAppAPI.outputs.name
// output API_CONTAINER_APP_FQDN string = containerAppAPI.outputs.fqdn
// output AZURE_CONTAINER_ENVIRONMENT_NAME string = managedEnvironment.outputs.name
