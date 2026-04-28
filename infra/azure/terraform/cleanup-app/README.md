# Getting Started Guide for Cleanup App
This guide will help you get started with the `rg-cleanup` tool, which cleans up stale Azure resource groups based on resource group tags. GitHub Repository: [Azure/rg-cleanup - Clean up stale Azure resource groups based on resource group tag](https://github.com/Azure/rg-cleanup/).

As of now we use the [README](https://github.com/Azure/rg-cleanup/blob/master/README.md) for cleanup app as we are blocked to create Logic Apps and Api Connections for it via terraform. It needs to be done via ARM templates are terraform doesnt support linking a Logic App to an Api Connection. Read more at: [Issue](https://github.com/hashicorp/terraform-provider-azurerm/pull/15797)

## Prerequisites

- The cleanup image hosted in an ACR 
- Service principal credentials or User Assigned Managed Identity (CLIENT_ID)
- An Azure subscription
- A resource group to host the Logic App in

## The cleanup image 

It can be built using the [Makefile](https://github.com/Azure/rg-cleanup/blob/master/Makefile). And hosted on the ACR. Note: The ACR needs to have anonymous pull enabled.

```sh
az acr update --name myregistry --anonymous-pull-enabled
```

## Build the rg-cleanup Tool
### Set Up Environment Variables

Export the necessary environment variables:

```sh
export AAD_CLIENT_ID="6e8b222a-b0ad-4336-a7e7-ec613c7d03a7"
export SUBSCRIPTION_ID="46678f10-4bbb-447e-98e8-d2829589f2d8"
```

### Build the tool

```sh
make
./bin/rg-cleanup --identity
```

### Deploy the Logic App

Use the Azure CLI to deploy the Logic App using the provided Bicep template:

```sh
az deployment group create -g "<rg-name>" -f ./templates/rg-cleaner-logic-app-uami.bicep --parameter \
    uami="<UAMI Name>" \ # Required
    uami_client_id="<UAMI Client ID>" \ # Required
    image="<rg-cleanup image url>" \ # Required
    dryrun="(false|true)" \ # Optional (default: true)
    ttl="<ttl>" \ # Optional
    regex="<regex expression patter>" # Optional
# Other optional parameters are available, please refer to the deployment bicep file.
```
