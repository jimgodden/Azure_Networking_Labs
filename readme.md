# Azure Networking Focused Bicep/ARM Lab Templates

## Introduction

This is a consolidated repository where I keep all of my Azure Bicep templates (and the compiled ARM templates) for deploying generic Azure Networking related lab environments.  These labs are intended for personal and training usage only.  They should not be used as is in a production environment.

## Instructions

This repository contains Bicep and ARM lab templates, scripts to be ran on Virtual Machines via Azure's customscriptextension, and tools that assist with deploying and managing the templates.

There are two ways to deploy the lab templates into an Azure subscription:

1. Click on the "Deploy to Azure" button which is in every depoyment folder's readme
2. Download this entire repository, open a PowerShell window at the location of folder that the repostory was downloaded to, and click on the deployment.ps1 file in the deployment's folder.
    - Prerequisites:
        - Azure PowerShell 
        - Azure Bicep - Manual install required to be used in PowerShell

Each deployment (with very few exceptions) uses the following file structure

- Deployment_* - Folder that contains labs of type Sandbox, Scenario, or Training
    - "Deployment Name"
        - src
            - main.bicep - contains the Bicep template
            - main.json - contains the ARM template (compiled from Bicep)
        - deployment.ps1 - deploys the lab via Bicep if the repository has been downloaded locally
        - diagram.drawio.png - Either contains a blank page or a diagram of the defined resources
        - readme.md - Contains a link to directly deploy the ARM template to the users Azure Portal.  May also contain additional instructions

## About the Deployments

There are three different type of Lab environments which can be found in the following folders

* Deployment_Sandbox
* Deployment_Scenario
* Deployment_Training

### Sandbox

These templates are created as complete deployments for the product whose name is in the title of the subsequent folder.  The template contains resource declarations for not only the resource named in the title, but also other resources that are needed to either contain or interact with the resource.  

For example, PrivateLink will deploy a Client Virtual Machine, Virtual Network, and Private Endpoint that connects to the Private Link Service which has an associated Load Balancer and Backend pool members to which the full functionality of the Private Link can be tested.

Each deployment offers several configurable parameters that can affect the main resource as well as some of the other connected resources.  However, some configuration options will only be possible after the lab has been deployed.  These can be modified in the Azure Portal as needed.

### Scenario

These templates are created for one specific use.  They are typically created for my own personal purposes as well as a few other individuals.  These labs are only relevant to individuals that have been specifically notified about them.  This is a volatile section which not be maintained.  It is not recommended to rely on these being available.  The recomendation is to ignore this section unless otherwise directed.

### Training

These templates are created to be used in conjunction with directed Trainings.  They are stored here for development purposes only.  These are not the official and final training templates.  Those will be stored in a private location.


