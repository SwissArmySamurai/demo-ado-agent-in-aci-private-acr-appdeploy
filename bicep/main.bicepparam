using './main.bicep'

// Hover over parameters to view descriptions
// Change parameter values to customise deployment if you wish
param location = 'uksouth'
param rgName = 'rg-ado-uks-demo'
param rgWebAppName = 'rg-ado-uks-webapp-demo'
param acrName = '' // Fill this out. It needs to be globally unique 
param acrSku = 'Premium'
param aciName = 'ado-agent'
param tags = {
  environment: 'demo'
  project: 'aci-ado-agent-demo'
}
param addressPrefix = '10.0.0.0/21'
param subnetPrefix = '10.0.1.0/26'
param subnetPEPrefix = '10.0.2.0/26'
param subnetADOPrefix = '10.0.3.0/24'
param peAddress = '10.0.2.6'
param peAddressAcr = '10.0.2.4'
param vNetName = 'vnet-ado-uks-demo'
param nsgName = 'nsg-ado-uks-demo'
param webAppName = 'app-ado-uks-demo'
param webAppPlanName = 'app-plan-ado-uks-demo'
param webAppNic = 'app-ado-uks-demo-pe-nic'
param acrNic = 'acr-ado-uks-demo-pe-nic'
param natGatewayName = 'natgw-ado-uks-demo'
param natGatewayPipName = 'natgw-pip-ado-uks-demo'
param webPlanSize = 'B1'
param webPlanTier = 'Basic'
// ADO Agent
param AZP_NAME = 'self-hosted' // Leave this value unless you're editing the modules to change the agent name
param AZP_POOL = 'Default' // Leave this value unless you're editing the modules to change the pool name
param AZP_TOKEN = 'ADO_PAT' // enter your ADO PAT here or use the override CLI parameter cmdlet. For anything other than lab/demo move this value to your ADO library/keyvault 
param AZP_URL = 'https://dev.azure.com/ADO_ORG'
param aciImage = 'mcr.microsoft.com/azuredocs/aci-helloworld:latest' // change this on second deployment pass. See (https://rios.engineer/private-azure-devops-agent-azure-container-instance-with-private-azure-container-registry) for more info. 
// placeholder public image. Change parameter to: ${acrName}.azurecr.io/ado-agent:latest on second deployment pass
// Git Repo 
param gitRepoUrl = 'https://dev.azure.com/ADO_ORG/ADO_PROJECT/_git/REPO_NAME#main' // change to your ADO repo URL
