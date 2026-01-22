@description('Deploys a vHub in another location for multi region connectivity if set to True.')
param multiRegion bool = true

@description('Azure Datacenter location that the main resouces will be deployed to.')
param mainLocation string = 'eastus2'

@description('Azure Datacenter location that the branch resouces will be deployed to.  This can be left blank if you are not deploying the hub in multiple regions')
param branchLocation string = 'westus2'

@description('Azure Datacenter location that the "OnPrem" resouces will be deployed to.')
param onPremLocation string = 'eastus'

@description('Admin Username for the Virtual Machines that gets placed in each Virtual Network')
param virtualMachine_AdminUsername string

@description('Password for the Admin User of the Virtual Machines that gets placed in each Virtual Network')
@secure()
param virtualMachine_AdminPassword string

@description('VPN Shared Key used for authenticating VPN connections.  This Shared Key must be the same key that is used on the Virtual Network Gateway that is being connected to the vWAN\'s S2S VPNs.')
@secure()
param vpn_SharedKey string

// var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'


module virtualWAN '../../../modules/Microsoft.Network/VirtualWAN.bicep' = {
  name: 'virtualWAN'
  params: {
    location: mainLocation
    virtualWAN_Name: 'vwan'
  }
}

//
// Virtual Hub A Start
//

module virtualHubA_and_Contents 'modules/AzureResources/VirtualHub_and_Contents.bicep' = {
  name: 'vHubA'
  params: {
    virtualNetwork_VirtualHub_AddressPrefix: '10.110.0.0/16'
    virtualNetwork_AddressPrefixs: ['10.111.0.0/16', '10.112.0.0/16']
    location: mainLocation
    usingAzureFirewall: true
    usingVPN: true
    virtualHub_UniquePrefix: 'A'
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualWAN_ID: virtualWAN.outputs.virtualWAN_ID
  }
}

module vHubA_to_OnPrem 'modules/AzureResources/VWANToVNGConnection.bicep' = {
  name: 'vhubA_to_OnPrem'
  params: {
    destinationVPN_ASN: OnPremResources.outputs.virtualNetworkGateway_ASN
    destinationVPN_BGPAddress: OnPremResources.outputs.virtualNetworkGateway_BGPAddress
    destinationVPN_Name: OnPremResources.outputs.virtualNetworkGateway_Name
    destinationVPN_PublicAddress: OnPremResources.outputs.virtualNetworkGateway_PublicIPAddress
    location: mainLocation
    virtualHub_Name: virtualHubA_and_Contents.outputs.virtualHub_Name
    virtualHub_RouteTable_Default_ResourceID: virtualHubA_and_Contents.outputs.virtualHub_RouteTable_Default_ResourceID
    virtualWAN_ID: virtualHubA_and_Contents.outputs.virtualWAN_ID
    virtualWAN_VPNGateway_Name: virtualHubA_and_Contents.outputs.virtualWAN_ID
    vpn_SharedKey: vpn_SharedKey
  }
}

module virtualHubB_and_Contents 'modules/AzureResources/VirtualHub_and_Contents.bicep' = if (multiRegion) {
  name: 'vHubB'
  params: {
    virtualNetwork_VirtualHub_AddressPrefix: '10.120.0.0/16'
    virtualNetwork_AddressPrefixs: ['10.121.0.0/16', '10.122.0.0/16']
    location: branchLocation
    usingAzureFirewall: false
    usingVPN: false
    virtualHub_UniquePrefix: 'B'
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualWAN_ID: virtualWAN.outputs.virtualWAN_ID
  }
}

module vHubB_to_OnPrem 'modules/AzureResources/VWANToVNGConnection.bicep' = {
  name: 'vhubB_to_OnPrem'
  params: {
    destinationVPN_ASN: OnPremResources.outputs.virtualNetworkGateway_ASN
    destinationVPN_BGPAddress: OnPremResources.outputs.virtualNetworkGateway_BGPAddress
    destinationVPN_Name: OnPremResources.outputs.virtualNetworkGateway_Name
    destinationVPN_PublicAddress: OnPremResources.outputs.virtualNetworkGateway_PublicIPAddress
    location: branchLocation
    virtualHub_Name: virtualHubB_and_Contents.outputs.virtualHub_Name
    virtualHub_RouteTable_Default_ResourceID: virtualHubB_and_Contents.outputs.virtualHub_RouteTable_Default_ResourceID
    virtualWAN_ID: virtualHubB_and_Contents.outputs.virtualWAN_ID
    virtualWAN_VPNGateway_Name: virtualHubB_and_Contents.outputs.virtualWAN_ID
    vpn_SharedKey: vpn_SharedKey
  }
}

module OnPremResources 'modules/OnPremResources/OnPremResources.bicep' = {
  name: 'OnPremResources'
  params: {
    location: onPremLocation
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    usingAzureFirewall: false
    virtualNetwork_AddressPrefix: '10.200.0.0/16'
    azureFirewall_SKU: 'Basic'
  }
}

module OnPrem_to_VHubA 'modules/OnPremResources/VNGToVWANConnection.bicep' = {
  name: 'OnPrem_to_VHubA'
  params: {
    destinationVPN_ASN: virtualHubA_and_Contents.outputs.virtualHub_VPNGateway_ASN
    destinationVPN_BGPAddress: virtualHubA_and_Contents.outputs.virtualHub_VPNGateway_BGPAddresses
    destinationVPN_Name: virtualHubA_and_Contents.outputs.virtualHub_VPNGateway_Name_Array
    destinationVPN_PublicAddress: virtualHubA_and_Contents.outputs.virtualHub_VPNGateway_PublicIPAddresses
    location: onPremLocation
    source_VirtualNetworkGateway_ResourceID: OnPremResources.outputs.virtualNetworkGateway_ResourceID
    vpn_SharedKey: vpn_SharedKey
  }
}

module OnPrem_to_VHubB 'modules/OnPremResources/VNGToVWANConnection.bicep' = if (multiRegion) {
  name: 'OnPrem_to_VHubB'
  params: {
    destinationVPN_ASN: virtualHubB_and_Contents.outputs.virtualHub_VPNGateway_ASN
    destinationVPN_BGPAddress: virtualHubB_and_Contents.outputs.virtualHub_VPNGateway_BGPAddresses
    destinationVPN_Name: virtualHubB_and_Contents.outputs.virtualHub_VPNGateway_Name_Array
    destinationVPN_PublicAddress: virtualHubB_and_Contents.outputs.virtualHub_VPNGateway_PublicIPAddresses
    location: onPremLocation
    source_VirtualNetworkGateway_ResourceID: OnPremResources.outputs.virtualNetworkGateway_ResourceID
    vpn_SharedKey: vpn_SharedKey
  }
}
