@description('Azure Datacenter location for the hub resources')
param location string = resourceGroup().location

@description('Azure Datacenter location for Region A')
param locationA string = 'eastus2'

@description('Azure Datacenter location for Region B')
param locationB string = 'westus2'

@description('Azure Datacenter location for Region C')
param locationC string = 'westeurope'

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

module virtualNetwork '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnetHub'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    virtualNetwork_Name: 'vnetHub'
  }
}

module bastion '../../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_name: 'Hub_Bastion'
    bastion_SubnetID: virtualNetwork.outputs.bastion_SubnetID
    location: location
  }
}

module logAnalyticsWorkspace '../../../modules/Microsoft.OperationalInsights/Workspaces.bicep' = {
  name: 'law'
  params: {
    location: location
    Workspaces_name: 'lawtest'
  }
}

module regionA './modules/Create_Client_And_WebServer.bicep' = {
  name: 'regionA'
  params: {
    location: locationA
    uniqueNamePrefix: 'A'
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
  }
}

module hub_to_A '../../../modules/Microsoft.Network/VirtualNetworkPeeringSpoke2Spoke.bicep' = {
  name: 'hub_to_A'
  params: {
    virtualNetwork1_Name: virtualNetwork.outputs.virtualNetwork_Name
    virtualNetwork2_Name: regionA.outputs.virtualNetwork_Name
  }
}

module regionB './modules/Create_Client_And_WebServer.bicep' = {
  name: 'regionB'
  params: {
    location: locationB
    uniqueNamePrefix: 'B'
    virtualNetwork_AddressPrefix: '10.2.0.0/16'
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
  }
}

module hub_to_B '../../../modules/Microsoft.Network/VirtualNetworkPeeringSpoke2Spoke.bicep' = {
  name: 'hub_to_B'
  params: {
    virtualNetwork1_Name: virtualNetwork.outputs.virtualNetwork_Name
    virtualNetwork2_Name: regionB.outputs.virtualNetwork_Name
  }
}

module regionC './modules/Create_Client_And_WebServer.bicep' = {
  name: 'regionC'
  params: {
    location: locationC
    uniqueNamePrefix: 'C'
    virtualNetwork_AddressPrefix: '10.3.0.0/16'
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
  }
}

module hub_to_C '../../../modules/Microsoft.Network/VirtualNetworkPeeringSpoke2Spoke.bicep' = {
  name: 'hub_to_C'
  params: {
    virtualNetwork1_Name: virtualNetwork.outputs.virtualNetwork_Name
    virtualNetwork2_Name: regionC.outputs.virtualNetwork_Name
  }
}
