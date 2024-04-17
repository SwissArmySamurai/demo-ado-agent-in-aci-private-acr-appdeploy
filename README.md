> [!TIP]
> Be sure to checkout my blog post on this which provides a comprehensive deep dive, insights, and step by step guide [here](https://rios.engineer/private-azure-devops-agent-azure-container-instance-with-private-azure-container-registry).

# Introduction

This repository will enable and showcase how you can deploy a fully private Azure DevOps self hosted agent on an Azure Container Instance, pulled from a fully private Azure Container Registry and deploy to an App Service behind a Private Endpoint.

The repo includes all the necessary components to deploy the Azure resources, Azure DevOps pipeline, .NET App.

This repository lab aims to help showcase and cut time from others who have difficulty achieving this solution due to the nature of limitations presented by a fully private Azure Container Registry with no public access. It will be applicable to any image to an ACI resource.

Initial deployment will create an ACI with a placeholder docker image pulled from a public source to facilitate a successful ACI deployment which further allows the manual ACR task run.

Once the private ACR image is built from your own private dockerfile then a redeployment following the steps will allow the ACI to pull the new image from the private ACR that is entirely private to your organisation vs public docker image.

## High Level Architecture

![Architecture Diagram](https://rios.engineer/wp-content/uploads/2024/03/ado-agent-aci-feature.png)

## Pre reqs

- Azure DevOps Project
- Azure subscription to deploy into
- Azure DevOps Service Connection (workload federation identity strongly recommended) that has `contributor` access to your Azure subscription
- Familiar with GIT

## Deploy

It's advised to read the blog for further information but here is a quick deployment flow tldr;

1. Clone this repo to your private Azure DevOps git repository
2. Create a PAT with `Code: Read` & `Agent Pools: Read & Manage` permission scopes
3. Create a new pipeline using an existing YAML file and select the `deploy-app.yaml` file, amending the variables for your ARM connection name
4. Add the relevant config details under the ADO Agent parameters in `main.bicepparam`
5. Deploy the Azure resources

```bash
az deployment sub create -l uksouth -n deploy -f main.bicep -p main.bicepparam
```

6. Connect to the Azure Container Instance terminal & run (or make a commit to the Dockerfile)

```bash
az login --identity
az acr task run --resource-group rg-ado-uks-demo -r YOURACR --name adoAgentBuildTask
```

7. Uncomment lines 45 to 51 in the `aci.bicep` module file and save
8. Amend the `aciImage` parameter in the `main.bicepparam` file to from `'emberstack/azure-pipelines-agent'` to `'${acrName}.azurecr.io/ado-agent:latest'`
9. Redeploy the Bicep template again using the commands from step 5 to pull the private ACR image into the ACI

> [!NOTE]  
> Feel free to fork this repo and customise the Bicep code as you see fit if you feel comfortable doing so. I have hard-coded some values for simplicity of the demo (e.g. repository name / tag).
