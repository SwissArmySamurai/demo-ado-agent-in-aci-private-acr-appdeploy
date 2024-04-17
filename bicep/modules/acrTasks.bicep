@description('Azure Container Registry name.')
param acrName string

@description('Azure DevOps git repository URL.')
param gitRepoUrl string

@description('Azure DevOps PAT task token.')
param AZP_PAT string

@description('ACR task location.')
param location string

@description('User assigned managed identity resource Id.')
param userManagedIdentityId string

resource buildTask 'Microsoft.ContainerRegistry/registries/tasks@2019-06-01-preview' = {
  name: '${acrName}/adoAgentBuildTask'
  location: location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities:{  
      '${userManagedIdentityId}': {}
     }
  }
  properties: {
    credentials:{
      sourceRegistry: {
        loginMode: 'Default'
      }
      customRegistries: {
        '${acrName}.azurecr.io': {
          identity: '[system]'
        }
    }
  }
  status: 'Enabled'
    platform: {
      os: 'linux'
      architecture: 'amd64'
    }
    step: {
      type: 'Docker'
      imageNames: [
        'ado-agent:latest' // {{.Run.ID}} can be used as an alternative to latest for anything other than demo purposes
      ]
      dockerFilePath: 'Dockerfile'
      contextPath: gitRepoUrl
      contextAccessToken: AZP_PAT
      isPushEnabled: true
    }
    trigger: {
      sourceTriggers: [
        {

          sourceRepository: {
            sourceControlType: 'VisualStudioTeamService'
            repositoryUrl: gitRepoUrl
            branch: 'main'
            sourceControlAuthProperties: {
              token: AZP_PAT
              tokenType: 'PAT'
            }
          }
          sourceTriggerEvents: [
            'commit'
          ]
          status: 'Enabled'
          name: 'defaultSourceTriggerName'
        }
      ]
    }
    isSystemTask: false
  }
}

output buildTaskResourceId string = buildTask.id
output buildTaskIdentityPrincipalId string = buildTask.identity.principalId
