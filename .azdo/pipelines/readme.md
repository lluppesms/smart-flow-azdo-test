# Azure DevOps Deployment Notes

## Azure DevOps Pipeline Definitions

Typically, you would want to set up either the first option or the second and third option, but not all three jobs.

- **[infra-only-pipeline.yml](infra-only-pipeline.yml):** Deploys the main-complete.bicep template and does nothing else
- **[aca-deploy-pipeline.yml]([aca-deploy-pipeline.yml):** Builds the app and deploys it to Azure
- **[infra-and-aca-deploy-pipeline.yml](infra-and-aca-deploy-pipeline.yml):** Deploys the main-complete.bicep template, builds the app, then deploys it to Azure
- **[build-pr-pipeline.yml](build-pr-pipeline.yml):** Runs each time a Pull Request is submitted and includes results in the PR
- **[scan-pipeline.yml](scan-pipeline.yml):** Runs a periodic scan of the app for security vulnerabilities

---

## Deploy Environments

These Azure DevOps YML files were designed to run as multi-stage environment deploys (i.e. DEV/QA/PROD). Each Azure DevOps environments can have permissions and approvals defined. For example, DEV can be published upon change, and QA/PROD environments can require an approval before any changes are made. These will be created automatically when the pipelines are run, but if you want to add approvals, you can do so in the Azure DevOps portal.

---

## Create the variable group "AI.Doc.Review.Keys"

This project needs a variable group with at least one variable in it that uniquely identifies your resources.

To create this variable groups, customize and run this command in the Azure Cloud Shell, or you can go into the Azure DevOps portal and create it manually.

> Alternatively, you could define these variables in the Azure DevOps Portal on each pipeline, but a variable group is a more repeatable and maintainable way to do it.

```bash
   az login

   az pipelines variable-group create
     --organization=https://dev.azure.com/<yourAzDOOrg>/
     --project='<yourAzDOProject>'
     --name AI.Doc.Review.Keys
     --variables
         appName='<uniqueString>-ai-doc-review'
```

## Create Service Connections and update the Service Connection Variable File

The pipelines use unique Service Connection names for each environment (dev/qa/prod), and can be configured to be any name of your choosing. By default, they are set up to be a simple format of `<env> Service Connection`. Edit the [vars\var-service-connections.yml](./vars\var-service-connections.yml) file to match what you have set up as your service connections.

See [Azure DevOps Service Connections](https://learn.microsoft.com/en-us/azure/devops/pipelines/library/connect-to-azure) for more info on how to set up service connections.

```bash
- name: serviceConnectionName
  value: 'DEV Service Connection'
- name: serviceConnectionDEV
  value: 'DEV Service Connection'
- name: serviceConnectionQA
  value: 'QA Service Connection'
- name: serviceConnectionProd
  value: 'PROD Service Connection'
```

## Update the Common Variables File with your settings

Customize your deploy by editing the [vars\var-common.yml](./vars\var-common.yml) file. This file contains the following variables which you can change:

```bash
- name: location
  value: 'westus'
```

## Set up the Deploy Pipelines

The Azure DevOps pipeline files exist in your repository and are defined in the `.azdo/pipelines` folder. However, in order to actually run them, you need to configure each of them using the Azure DevOps portal.

Set up each of the desired pipelines using [these steps](../../docs/CreateNewPipeline.md).

---

You should be all set to go now!

---

[Home Page](../../README.md)
