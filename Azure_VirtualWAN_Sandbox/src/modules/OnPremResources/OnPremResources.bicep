@description('Azure Datacenter location that the main resouces will be deployed to.')
param location string

// @description('Address Prefix of the Virtual Network.')
// param firstTwoOctetsOfVirtualNetworkPrefix string

@description('Address Prefix of the Virtual Network.')
param virtualNetwork_AddressPrefix string

@description('Deploys a Az FW if true')
param usingAzureFirewall bool

@description('Sku name of the Azure Firewall.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param azureFirewall_SKU string = 'Basic'

@description('Admin Username for the Virtual Machine')
param virtualMachine_AdminUsername string

@description('Password for the Virtual Machine Admin User')
@secure()
param virtualMachine_AdminPassword string

module virtualNetwork_Hub '../../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'OnPrem_VNET'
  params: {
    location: location
    // firstTwoOctetsOfVirtualNetworkPrefix: firstTwoOctetsOfVirtualNetworkPrefix
    virtualNetwork_AddressPrefix: virtualNetwork_AddressPrefix
    virtualNetwork_Name: 'OnPrem_VNet_Hub'
  }
}

module firewall '../../../../modules/Microsoft.Network/AzureFirewall.bicep' =  if (usingAzureFirewall) {
  name: 'OnPrem_AzFW'
  params: {
    azureFirewall_Name: 'OnPrem_AzFW'
    azureFirewall_SKU: azureFirewall_SKU
    azureFirewallPolicy_Name: 'OnPrem_AzFWPolicy'
    azureFirewall_Subnet_ID: virtualNetwork_Hub.outputs.azureFirewall_SubnetID
    azureFirewall_ManagementSubnet_ID: virtualNetwork_Hub.outputs.azureFirewallManagement_SubnetID
    location: location
  }
  // Azure Firewall fails to deploy if the Azure Virtual Network Gateway is still deploying
  dependsOn: [
    vpn
  ]
}

module vpn '../../../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'OnPrem_VPN'
  params: {
    location: location
    virtualNetworkGateway_Name: 'OnPrem_VirtualNetworkGateway'
    virtualNetworkGateway_ASN: 65301
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork_Hub.outputs.gateway_SubnetID
  }
}

module bastion '../../../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'OnPrem_Bastion'
  params: {
    bastion_name: '${virtualNetwork_Hub.outputs.virtualNetwork_Name}_Bastion'
    bastion_SubnetID: virtualNetwork_Hub.outputs.bastion_SubnetID
    location: location
  }
}

module virtualMachine_Windows '../../../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'OnPrem_WinVM'
  params: {
    acceleratedNetworking: false
    location: location
    subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'OnPremWinVM'
    virtualMachine_Size: 'B2ms'
    virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/Refactoring/scripts/'
    virtualMachine_ScriptFileName: 'WinServ2022_General_InitScript.ps1'
  }
}

output virtualNetworkGateway_ResourceID string = vpn.outputs.virtualNetworkGateway_ResourceID
output virtualNetworkGateway_Name string = vpn.outputs.virtualNetworkGateway_Name
output virtualNetworkGateway_PublicIPAddress string = vpn.outputs.virtualNetworkGateway_PublicIPAddress
output virtualNetworkGateway_BGPAddress string = vpn.outputs.virtualNetworkGateway_BGPAddress
output virtualNetworkGateway_ASN int = vpn.outputs.virtualNetworkGateway_ASN

























