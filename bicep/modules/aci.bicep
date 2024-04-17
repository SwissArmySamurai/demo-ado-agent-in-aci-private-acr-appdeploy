@description('Azure Container Instance name.')
param aciName string

@description('Azure resource location.')
param location string

@description('Azure Subnet name.')
param subnetId string

@description('Azure DevOps Organisation URL.')
param AZP_URL string

@description('Azure DevOps agent name.')
param AZP_NAME string

@description('Azure DevOps PAT token for agent registration.')
param AZP_TOKEN string

@description('Azure DevOps Pool name.')
param AZP_POOL string

@description('Azure tags.')
param tags object

@description('Azure Container Image.')
param aciImage string 

@description('User assigned managed identity resource Id.')
param userManagedIdentityId string

@description('ACR Name.')
param acrName string

resource containerInstance 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: aciName
  location: location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities:{  
      '${userManagedIdentityId}': {}
     }
  }
  properties: {
    sku: 'Standard'
    /*
    imageRegistryCredentials:[
      {
        server: '${acrName}.azurecr.io'
        identity: userManagedIdentityId
      }
    ]*/
    containers: [
      {
        name: aciName
        properties: {
          image: aciImage
          ports: [
            {
              protocol: 'TCP'
              port: 80
            }
          ]
          environmentVariables: [
            {
              name: 'AZP_URL'
              value: AZP_URL
            }
            {
              name: 'AZP_AGENT_NAME'
              value: AZP_NAME
            }
            {
              name: 'AZP_TOKEN'
              secureValue: AZP_TOKEN
            }
            {
              name: 'AZP_POOL'
              value: AZP_POOL
            }
          ]
          resources: {
            requests: {
              memoryInGB: 2
              cpu: 1
            }
          }
        }
      }
    ]
    restartPolicy: 'Always'
    ipAddress: {
      ports: [
        {
          protocol: 'TCP'
          port: 80
        }
      ]
      type: 'Private'
    }
    osType: 'Linux'
    subnetIds: [
      {
        id: subnetId
      }
    ]
  }
  tags: tags
}


output systemAssignedIdentityId string = containerInstance.identity.principalId
output containerInstancePrincipalId string = containerInstance.identity.principalId
output containerInstanceResourceId string = containerInstance.id
