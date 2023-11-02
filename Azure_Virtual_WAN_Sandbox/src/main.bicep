targetScope = 'subscription'

@description('Deploys a vHub in another location for multi region connectivity if set to True.')
param multiRegion bool = true

@description('Name of the Resource Group that the MainHub will be deployed to.')
param mainRG_Name string = 'VWAN_Sandbox_Main_RG'

@description('Azure Datacenter location that the main resouces will be deployed to.')
param mainLocation string = 'eastus2'

@description('Name of the Resource Group that the MainHub will be deployed to.')
param branchRG_Name string = 'VWAN_Sandbox_Branch_RG'

@description('Azure Datacenter location that the branch resouces will be deployed to.  This can be left blank if you are not deploying the hub in multiple regions')
param branchLocation string = 'westus2'

@description('Name of the Resource Group that the MainHub will be deployed to.')
param onPremRG_Name string = 'VWAN_Sandbox_OnPrem_RG'

@description('Azure Datacenter location that the "OnPrem" resouces will be deployed to.')
param onPremLocation string = 'eastus'

@description('Name of the Virtual WAN resource')
param VWAN_Name string = 'vwan'

@description('Admin Username for the Virtual Machines that gets placed in each Virtual Network')
param vm_AdminUserName string

@description('Password for the Admin User of the Virtual Machines that gets placed in each Virtual Network')
@secure()
param vm_AdminPassword string

@description('VPN Shared Key used for authenticating VPN connections.  This Shared Key must be the same key that is used on the Virtual Network Gateway that is being connected to the vWAN\'s S2S VPNs.')
@secure()
param vpn_SharedKey string

@description('ASN of the On Prem VPN')
param OnPrem_ASN int = 65200

@description('ASN of the VWAN VPN')
var VWAN_ASN = 65515

resource MainRG 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: mainRG_Name
  location: mainLocation
}

resource BranchRG 'Microsoft.Resources/resourceGroups@2022-09-01' = if (multiRegion) {
  name: branchRG_Name
  location: branchLocation
}

resource OnPremRG 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: onPremRG_Name
  location: onPremLocation
}

module vWAN 'modules/Networking/vwan.bicep' = {
  scope: MainRG
  name: 'virtualWAN'
  params: {
    location: mainLocation
    VWAN_Name: VWAN_Name
  }
}

module mainHub './modules/Networking/hubAndContents.bicep' = {
  name: 'mainHub'
  scope: MainRG
  params: {
    location: mainLocation
    vwanID: vWAN.outputs.vwanID
    vm_AdminUserName: vm_AdminUserName
    vm_AdminPassword: vm_AdminPassword
    vHub_Iteration: 1
    usingVPN: true
    usingAzFW: true
  }
}

module MainvHubVNetConn_1 './modules/Networking/hubVirtualNetworkConnections.bicep' = {
  name: 'Main_vHub_to_vnet1_Conn'
  scope: MainRG
  params: {
    vHubName: mainHub.outputs.vHubName
    vHubRouteTableDefaultID: mainHub.outputs.vHubRouteTableDefaultID
    vnetID: mainHub.outputs.vnetID1
    vnetName: mainHub.outputs.vnetName1
  }
}

module MainHub_To_OnPrem 'modules/Networking/VWANToVNGConnection.bicep' = {
  name: 'MainHub_To_OnPrem'
  scope: MainRG
  params: {
    destinationVPN_ASN: OnPremResources.outputs.onpremVNGASN
    destinationVPN_BGPAddress: OnPremResources.outputs.onPremVNGBGPAddress
    destinationVPN_Name: OnPremResources.outputs.onpremVNGName
    destinationVPN_PublicAddress: OnPremResources.outputs.onpremVNGPIP
    location: mainLocation
    vhub_name: mainHub.outputs.vHubName
    vHub_RouteTable_Default_ResourceID: mainHub.outputs.vHubRouteTableDefaultID
    vpn_SharedKey: vpn_SharedKey
    vwan_VPN_Name: mainHub.outputs.vpnName
    vwanID: vWAN.outputs.vwanID
  }
}

module branchHub './modules/Networking/hubAndContents.bicep' = if (multiRegion) {
  name: 'branchHub1'
  scope: BranchRG
  params: {
    location: branchLocation
    vwanID: vWAN.outputs.vwanID
    vm_AdminUserName: vm_AdminUserName
    vm_AdminPassword: vm_AdminPassword
    vHub_Iteration: 2
    usingVPN: true
    usingAzFW: false
  }
}

module BranchvHubVNetConn_1_1 './modules/Networking/hubVirtualNetworkConnections.bicep' = if (multiRegion) {
  name: 'Branch1_vHub_to_vnet1_Conn'
  scope: BranchRG
  params: {
    vHubName: branchHub.outputs.vHubName
    vHubRouteTableDefaultID: branchHub.outputs.vHubRouteTableDefaultID
    vnetID: branchHub.outputs.vnetID1
    vnetName: branchHub.outputs.vnetName1
  }
}

module BranchHub_To_OnPrem 'modules/Networking/VWANToVNGConnection.bicep' = if (multiRegion) {
  name: 'BranchHub_To_OnPrem'
  scope: BranchRG
  params: {
    destinationVPN_ASN: OnPremResources.outputs.onpremVNGASN
    destinationVPN_BGPAddress: OnPremResources.outputs.onPremVNGBGPAddress
    destinationVPN_Name: OnPremResources.outputs.onpremVNGName
    destinationVPN_PublicAddress: OnPremResources.outputs.onpremVNGPIP
    location: branchLocation
    vhub_name: branchHub.outputs.vHubName
    vHub_RouteTable_Default_ResourceID: branchHub.outputs.vHubRouteTableDefaultID
    vpn_SharedKey: vpn_SharedKey
    vwan_VPN_Name: branchHub.outputs.vpnName
    vwanID: vWAN.outputs.vwanID
  }
}

module OnPremResources 'modules/OnPremResources/main_OnPremResources.bicep' = {
  name: 'OnPremResources'
  scope: OnPremRG
  params: {
    location: onPremLocation
    vm_AdminPassword: vm_AdminPassword
    vm_AdminUserName: vm_AdminUserName
    OnPrem_VNG_ASN: OnPrem_ASN
    usingAzFW: false
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
