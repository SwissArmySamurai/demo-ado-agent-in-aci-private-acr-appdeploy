targetScope = 'subscription'

metadata name = 'Azure DevOps Agent using Azure Container Instance'
metadata description = 'This Azure Bicep template deploys all the necessary components to create a self-hosted Azure DevOps agent to run on private Container Instances with a private App service example to deploy to.'
metadata owner = 'Dan Rios - https://rios.engineer'

@description('Required. Azure Resource locations - limited to regions where ACR Tasks/Pools are currently supported.')
param location string

@description('Required. Azure Resource Group name.')
param rgName string

@description('Required. Azure Web App Resource Group name.')
param rgWebAppName string

@description('Creation time tag.')
param timeNow string = utcNow()

@description('Required. Azure Container Registry name.')
param acrName string

@description('Required. Azure Container Registry SKU.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string

@description('Required. Azure Virtual Network name.')
param vNetName string

@description('Required. Network Security Group name.')
param nsgName string

@description('Required. Azure Virtual Network name.')
param addressPrefix string

@description('Required. vNet subnet IP address prefix.')
param subnetPrefix string

@description('Required. vNet PE subnet IP address prefix.')
param subnetPEPrefix string

@description('Required. Static PE IP address for Web App.')
param peAddress string

@description('Required. Static PE IP address for ACR.')
param peAddressAcr string

@description('Required. vNet ADO subnet IP address prefix.')
param subnetADOPrefix string

@description('Required. Azure Web App name.')
param webAppName string

@description('Required. Azure App plan name.')
param webAppPlanName string

@description('Required. Azure App Private Endpoint NIC name.')
param webAppNic string

@description('Required. Azure Container Registry NIC name.')
param acrNic string

@description('Required. Azure NAT Gateway resource name.')
param natGatewayName string

@description('Required. Azure NAT Gateway Public IP resource name.')
param natGatewayPipName string

@description('Required. Azure App plan tier.')
@allowed([
  'Free'
  'Basic'
  'Premium'
])
param webPlanTier string

@description('Required. Azure App plan size. e.g. F1, B1, P1V3.')
param webPlanSize string

@description('Required. Azure resource tags.')
param tags object

@description('Required. Azure Container Instance name.')
param aciName string

@description('Azure DevOps Organisation URL.')
param AZP_URL string

@description('Azure DevOps agent name.')
param AZP_NAME string

@description('Azure DevOps PAT token for agent registration.')
@secure()
param AZP_TOKEN string

@description('Azure DevOps Pool name.')
param AZP_POOL string

@description('Azure DevOps Git repository URL.')
param gitRepoUrl string

@description('Azure Container Image.')
param aciImage string

module rg 'br/public:avm/res/resources/resource-group:0.2.3' = {
  name: '${uniqueString(deployment().name, location)}-rg'
  params: {
    name: rgName
    location: location
    tags: union(tags, { creation: timeNow })
  }
}

module rgWebApp 'br/public:avm/res/resources/resource-group:0.2.3' = {
  name: '${uniqueString(deployment().name, location)}-rgWebApp'
  params: {
    name: rgWebAppName
    location: location
    tags: union(tags, { creation: timeNow })
  }
}

module pip 'br/public:avm/res/network/public-ip-address:0.3.1' = {
  name: '${uniqueString(deployment().name, location)}-pip'
  scope: resourceGroup('${rgName}')
  params: {
    name: natGatewayPipName
    location: location
    tags: tags
  }
  dependsOn: [
    rgWebApp
  ]
}

module natGateway 'br/public:avm/res/network/nat-gateway:1.0.4' = {
  name: '${uniqueString(deployment().name, location)}-natGateway'
  scope: resourceGroup('${rgName}')
  params: {
    name: natGatewayName
    location: location
    tags: tags
    publicIpResourceIds: [
      pip.outputs.resourceId
    ]
  }
  dependsOn: [
    rgWebApp
  ]
}

module nsg 'br/public:avm/res/network/network-security-group:0.1.3' = {
  name: '${uniqueString(deployment().name, location)}-nsg'
  scope: resourceGroup('${rgWebAppName}')
  params: {
    name: nsgName
    location: location
    tags: union(tags, { creation: timeNow })
  }
  dependsOn: [
    rgWebApp
  ]
}

module vNet 'br/public:avm/res/network/virtual-network:0.1.5' = {
  name: '${uniqueString(deployment().name, location)}-vNet'
  scope: resourceGroup('${rgWebAppName}')
  params: {
    name: vNetName
    location: location
    tags: union(tags, { creation: timeNow })
    addressPrefixes: [
      addressPrefix
    ]
    subnets: [
      {
        name: 'webApp-snet'
        addressPrefix: subnetPrefix
        networkSecurityGroupResourceId: nsg.outputs.resourceId
        delegations: [
          {
            name: 'Microsoft.Web.serverFarms'
            properties: {
              serviceName: 'Microsoft.Web/serverFarms'
            }
          }
        ]
      }
      {
        name: 'webApp-pe-snet'
        addressPrefix: subnetPEPrefix
        networkSecurityGroupResourceId: nsg.outputs.resourceId
      }
      {
        name: 'webApp-ado-snet'
        addressPrefix: subnetADOPrefix
        networkSecurityGroupResourceId: nsg.outputs.resourceId
        delegations: [
          {
            name: 'Microsoft.ContainerInstance'
            properties: {
              serviceName: 'Microsoft.ContainerInstance/containerGroups'
            }
          }
        ]
        natGatewayResourceId: natGateway.outputs.resourceId
      }
    ]
  }
  dependsOn: [
    rgWebApp
  ]
}

module webFarm 'br/public:avm/res/web/serverfarm:0.1.1' = {
  name: '${uniqueString(deployment().name, location)}-webFarm'
  scope: resourceGroup('${rgWebAppName}')
  params: {
    name: webAppPlanName
    sku: {
      name: webPlanSize
      tier: webPlanTier
      size: webPlanSize
    }
    tags: union(tags, { creation: timeNow })
  }
  dependsOn: [
    rgWebApp
  ]
}

module webApp 'br/public:avm/res/web/site:0.3.1' = {
  name: '${uniqueString(deployment().name, location)}-webApp'
  scope: resourceGroup('${rgWebAppName}')
  params: {
    kind: 'app'
    name: webAppName
    serverFarmResourceId: webFarm.outputs.resourceId
    publicNetworkAccess: 'Disabled'
    location: location
    siteConfig:{
      healthCheckPath: '/'
      windowsFxVersion: 'DOTNET|7'
      netFrameworkVersion: 'v7.0'
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: 'dotnet'

        }
      ]
    }
    virtualNetworkSubnetId: vNet.outputs.subnetResourceIds[0]
    privateEndpoints: [
      {
        name: 'webApp-pe'
        subnetResourceId: vNet.outputs.subnetResourceIds[1]
        customNetworkInterfaceName: webAppNic
      }
    ]
    managedIdentities: {
      systemAssigned: true
    }
    tags: union(tags, { creation: timeNow })
  }
}

module userManagedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.0' = {
  scope: resourceGroup('${rgName}')
  name: '${uniqueString(deployment().name, location)}-umi'
  params: {
    name: 'ado-umi-uks-demo'
    location: location
    tags: union(tags, { creation: timeNow })
  }
  dependsOn: [
    rg
  ]
}

module acr 'br/public:avm/res/container-registry/registry:0.1.1' = {
  name: '${uniqueString(deployment().name, location)}-acr'
  scope: resourceGroup('${rgName}')
  params: {
    name: acrName
    location: location
    acrSku: acrSku
    acrAdminUserEnabled: false
    azureADAuthenticationAsArmPolicyStatus: 'enabled'
    publicNetworkAccess: 'Disabled' 
    networkRuleBypassOptions: 'AzureServices'
    managedIdentities: {
      systemAssigned: true
      userAssignedResourceIds: [
        userManagedIdentity.outputs.resourceId
      ]
    }
    privateEndpoints:[
      {
        name: 'acr-pe'
        customNetworkInterfaceName: acrNic
        subnetResourceId: vNet.outputs.subnetResourceIds[1]
      }
    ]
    tags: union(tags, { creation: timeNow })
  }
  dependsOn: [
    rg
  ]
}

module peDNS 'br/public:avm/res/network/private-dns-zone:0.2.4' = {
  name: '${uniqueString(deployment().name, location)}-peDNS'
  scope: resourceGroup('${rgWebAppName}')
  params: {
    name: 'privatelink.azurewebsites.net'
    location: 'global'
    tags: union(tags, { creation: timeNow })
    virtualNetworkLinks: [
      {
        name: 'webApp-pe'
        virtualNetworkResourceId: vNet.outputs.resourceId
      }
    ]
    a: [
      {
        aRecords: [
          {
            ipv4Address: peAddress
          }
        ]
        name: webAppName
        ttl: 300
      }
      {
        aRecords: [
          {
            ipv4Address: peAddress
          }
        ]
        name: '${webAppName}.scm'
        ttl: 300
      }
    ]
  }
}

module peDNSAcr 'br/public:avm/res/network/private-dns-zone:0.2.4' = {
  name: '${uniqueString(deployment().name, location)}-peDNSAcr'
  scope: resourceGroup('${rgName}')
  params: {
    name: 'privatelink.azurecr.io'
    location: 'global'
    tags: union(tags, { creation: timeNow })
    virtualNetworkLinks: [
      {
        name: 'acr-pe'
        virtualNetworkResourceId: vNet.outputs.resourceId
      }
    ]
    a: [
      {
        aRecords: [
          {
            ipv4Address: peAddressAcr
          }
        ]
        name: acrName
        ttl: 300
      }
    ]
  }
}


module acrBuildTask 'modules/acrTasks.bicep' = {
  name: '${uniqueString(deployment().name, location)}-acrBuildTask'
  scope: resourceGroup('${rgName}')
  params: {
    acrName: acrName
    location: location
    AZP_PAT: AZP_TOKEN
    gitRepoUrl: gitRepoUrl
    userManagedIdentityId: userManagedIdentity.outputs.resourceId
  }
  dependsOn: [
    acr
  ]
}


var contributor = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var reader = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
module roleAssignmentUMI 'br/public:authorization/resource-scope-role-assignment:1.0.2' = {
  scope: resourceGroup('${rgName}')
  name: 'acrRoleAssignment'
  params: {
    name: guid(userManagedIdentity.outputs.principalId, acr.outputs.resourceId)
    principalId: userManagedIdentity.outputs.principalId
    resourceId: acr.outputs.resourceId
    roleDefinitionId: contributor
  }
}

module roleAssignmentAciSysMI 'br/public:authorization/resource-scope-role-assignment:1.0.2' = {
  scope: resourceGroup('${rgName}')
  name: 'aciSysMIRoleAssignment'
  params: {
    name: guid(aci.outputs.containerInstancePrincipalId, acr.outputs.resourceId)
    principalId: aci.outputs.containerInstancePrincipalId
    resourceId: aci.outputs.containerInstanceResourceId
    roleDefinitionId: reader
  }
}

module roleAssignmentAci 'br/public:authorization/resource-scope-role-assignment:1.0.2' = {
  scope: resourceGroup('${rgName}')
  name: 'aciRoleAssignment'
  params: {
    name: guid(vNet.outputs.resourceId, acr.outputs.resourceId)
    principalId: aci.outputs.systemAssignedIdentityId
    resourceId: acr.outputs.resourceId
    roleDefinitionId: contributor
  }
}

module roleAssignmentAcrTask 'br/public:authorization/resource-scope-role-assignment:1.0.2' = {
  scope: resourceGroup('${rgName}')
  name: 'acrBuildTaskRoleAssignment'
  params: {
    name: guid(acrBuildTask.outputs.buildTaskResourceId, acr.outputs.resourceId)
    principalId: acrBuildTask.outputs.buildTaskIdentityPrincipalId
    resourceId: acr.outputs.resourceId
    roleDefinitionId: contributor
  }
}

module aci 'modules/aci.bicep' = {
  name: '${uniqueString(deployment().name, location)}-aci'
  scope: resourceGroup('${rgName}')
  params:{
    location: location
    AZP_NAME: AZP_NAME
    AZP_POOL: AZP_POOL
    AZP_TOKEN: AZP_TOKEN
    AZP_URL: AZP_URL
    subnetId: vNet.outputs.subnetResourceIds[2]
    aciName: aciName
    aciImage: aciImage
    userManagedIdentityId: userManagedIdentity.outputs.resourceId
    acrName: acrName
    tags: union(tags, { creation: timeNow })
  }
}
