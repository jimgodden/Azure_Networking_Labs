@description('Deploys a vHub in another location for multi region connectivity if set to True.')
param multiRegion bool = true

@description('Azure Datacenter location that the main resouces will be deployed to.')
param mainLocation string = 'eastus2'

@description('Azure Datacenter location that the branch resouces will be deployed to.  This can be left blank if you are not deploying the hub in multiple regions')
param branchLocation string = 'westus2'

@description('Azure Datacenter location that the "OnPrem" resouces will be deployed to.')
param onPremLocation string = 'eastus'

@description('Admin Username for the Virtual Machines that gets placed in each Virtual Network')
param virtualMachine_adminUsername string

@description('Password for the Admin User of the Virtual Machines that gets placed in each Virtual Network')
@secure()
param virtualMachine_adminPassword string

@description('VPN Shared Key used for authenticating VPN connections.  This Shared Key must be the same key that is used on the Virtual Network Gateway that is being connected to the vWAN\'s S2S VPNs.')
@secure()
param vpn_SharedKey string

@description('ASN of the VWAN VPN')
var VWAN_ASN = 65515

module virtualWAN '../../modules/Microsoft.Network/VirtualWAN.bicep' = {
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
    firstTwoOctetsOfVirtualHubNetworkPrefix: '10.110'
    firstTwoOctetsOfVirtualNetworkPrefix: ['10.111', '10.112']
    location: mainLocation
    usingAzureFirewall: true
    usingVPN: true
    virtualHub_UniquePrefix: 'A'
    virtualMachine_AdminPassword: virtualMachine_adminPassword
    virtualMachine_AdminUsername: virtualMachine_adminUsername
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
    firstTwoOctetsOfVirtualHubNetworkPrefix: '10.120'
    firstTwoOctetsOfVirtualNetworkPrefix: ['10.121', '10.122']
    location: branchLocation
    usingAzureFirewall: false
    usingVPN: false
    virtualHub_UniquePrefix: 'B'
    virtualMachine_AdminPassword: virtualMachine_adminPassword
    virtualMachine_AdminUsername: virtualMachine_adminUsername
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
    virtualMachine_AdminPassword: virtualMachine_adminPassword
    virtualMachine_AdminUsername: virtualMachine_adminUsername
    usingAzureFirewall: false
    firstTwoOctetsOfVirtualNetworkPrefix: '10.200'
    azureFirewall_SKU: 'Basic'
  }
}

module OnPrem_to_VHubA 'modules/OnPremResources/VNGToVWANConnection.bicep' = {
  name: 
  params: {
    bgpPeeringAddress_0: 
    bgpPeeringAddress_1: 
    gatewayIPAddress_0: 
    gatewayIPAddress_1: 
    location: 
    onPremVNGResourceID: 
    vhubIteration: 
    vpn_SharedKey: 
    VWAN_ASN: 
  }
}

module OnPrem_To_MainHub 'modules/Networking/VNGToVWANConnection.bicep' = {
  name: 'OnPrem_To_MainHub'
  scope: OnPremRG
  params: {
    bgpPeeringAddress_0: mainHub.outputs.vpnBGPIP0
    bgpPeeringAddress_1: mainHub.outputs.vpnBGPIP1
    gatewayIPAddress_0: mainHub.outputs.vpnPubIP0
    gatewayIPAddress_1: mainHub.outputs.vpnPubIP1
    VWAN_ASN: VWAN_ASN
    location: onPremLocation
    onPremVNGResourceID: OnPremResources.outputs.onPremVNGResourceID
    vhubIteration: 1
    vpn_SharedKey: vpn_SharedKey
  }
}

module OnPrem_To_BranchHub 'modules/Networking/VNGToVWANConnection.bicep' = if (multiRegion) {
  name: 'OnPrem_To_BranchHub'
  scope: OnPremRG
  params: {
    bgpPeeringAddress_0: branchHub.outputs.vpnBGPIP0
    bgpPeeringAddress_1: branchHub.outputs.vpnBGPIP1
    gatewayIPAddress_0: branchHub.outputs.vpnPubIP0
    gatewayIPAddress_1: branchHub.outputs.vpnPubIP1
    VWAN_ASN: VWAN_ASN
    location: onPremLocation
    onPremVNGResourceID: OnPremResources.outputs.onPremVNGResourceID
    vhubIteration: 2
    vpn_SharedKey: vpn_SharedKey
  }
}
