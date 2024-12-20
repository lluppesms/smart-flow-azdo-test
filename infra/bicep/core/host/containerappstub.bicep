@maxLength(32)
param appName string
param managedEnvironmentName string
param managedEnvironmentRg string
param imageName string = ''
param registryName string
param userAssignedIdentityName string

@description('The target port for the container')
param targetPort int = 80

param location string = resourceGroup().location
param tags object = {}

@description('The secrets required for the container, with the key being the secret name and the value being the key vault URL')
@secure()
param secrets object = {}

@description('The environment variables for the container')
param env array = []

// --------------------------------------------------------------------------------------------------------------

resource containerAppEnvironmentResource 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: managedEnvironmentName
  scope: resourceGroup(managedEnvironmentRg)
}

resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: userAssignedIdentityName
}


resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  tags: tags
  identity:{
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userIdentity.id}': {}
    }
  }
  properties: {
    environmentId: containerAppEnvironmentResource.id
    configuration: {
      ingress: {
        targetPort: targetPort
        external: true
      }
      secrets: [for secret in items(secrets): {
        name: secret.key
        identity: userIdentity.id
        keyVaultUrl: secret.value
      }]
      registries: [
        {
          identity: userIdentity.id
          server: '${registryName}.azurecr.io'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'app'
          image: !empty(imageName) ? imageName : 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
              cpu: json('0.5')
              memory: '1.0Gi'
          }
          env: env
          probes: [
            {
              type: 'startup'
              httpGet: {
                path: '/health'
                port: targetPort
              }
              initialDelaySeconds: 3
              periodSeconds: 1
            }
            {
              type: 'readiness'
              httpGet: {
                path: '/ready'
                port: targetPort
              }
              initialDelaySeconds: 3
              periodSeconds: 10
            }
            {
              type: 'liveness'
              httpGet: {
                path: '/health'
                port: targetPort
              }
              initialDelaySeconds: 7
              periodSeconds: 10
            }
          ]
        }
      ]
    }
  }
}

// output id string = containerApp.id
output name string = containerApp.name
output id string = containerApp.id
output fqdn string = containerApp.properties.configuration.ingress.fqdn
