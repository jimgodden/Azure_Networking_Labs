param location string

param virtualWAN_ID string

param virtualHub_UniquePrefix string

param firstTwoOctetsOfVirtualHubNetworkPrefix string

param firstTwoOctetsOfVirtualNetworkPrefix array

@secure()
param virtualMachine_AdminPassword string

param virtualMachine_AdminUsername string

param usingAzureFirewall bool

param usingVPN bool

module virtualHub '../../../../modules/Microsoft.Network/VirtualHub.bicep' = {
  name: 'vhub'
  params: {
    location: location
    virtualHub_AddressPrefix: '${firstTwoOctetsOfVirtualHubNetworkPrefix}.0.0/16'
    virtualHub_Name: 'vhub${virtualHub_UniquePrefix}'
    virtualWAN_ID: virtualWAN_ID
    usingAzureFirewall: usingAzureFirewall
    azureFirewall_SKU: 'Basic'
    usingVPN: usingVPN
  }
}

module virtualNetwork_Spoke '../../../../modules/Microsoft.Network/VirtualNetworkSpoke.bicep' = [ for i in range(1, length(firstTwoOctetsOfVirtualNetworkPrefix)): {
  name: 'spokeVNet${i}'
  params: {
    firstTwoOctetsOfVirtualNetworkPrefix: firstTwoOctetsOfVirtualNetworkPrefix[i]
    location: location
    virtualNetwork_Name: 'spoke${i}_VNet'
  }
} ]

module virtualHubToVirtualNetworkSpokeAConn '../../../../modules/Microsoft.Network/hubVirtualNetworkConnections.bicep' = [ for i in range(1, length(firstTwoOctetsOfVirtualNetworkPrefix)): {
  name: 'vhubA_to_spoke${i}_Conn'
  params: {
    virtualHub_Name: virtualHub.outputs.virtualHub_Name
    virtualHub_RouteTable_Default_ID: virtualHub.outputs.virtualHub_RouteTable_Default_ID
    virtualNetwork_ID: virtualNetwork_Spoke[i].outputs.virtualNetwork_ID
    virtualNetwork_Name: virtualNetwork_Spoke[i].outputs.virtualNetwork_Name
  }
} ]

module virtualMachine_Windows '../../../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = [ for i in range(1, length(firstTwoOctetsOfVirtualNetworkPrefix)): {
  name: 'windowsVM${i}'
  params: {
    acceleratedNetworking: false
    location: location
    subnet_ID: virtualNetwork_Spoke[i].outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'winVM${virtualHub.outputs.virtualHub_Name}${i}'
    virtualMachine_Size: 'B2ms'
    virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'
    virtualMachine_ScriptFileName: 'WinServ2022_General_InitScript.ps1'
  }
} ]

output virtualWAN_ID string = virtualWAN_ID

output virtualHub_Name string = virtualHub.outputs.virtualHub_Name
output virtualHub_RouteTable_Default_ResourceID string = virtualHub.outputs.virtualHub_RouteTable_Default_ID
output virtualWAN_VPNGateway_Name string = virtualHub.outputs.vpnGateway_Name

output virtualHub_VPNGateway_Name_Array array = virtualHub.outputs.vpnGateway_Name_Array
output virtualHub_VPNGateway_PublicIPAddresses array = virtualHub.outputs.vpnGateway_PublicIPAddresses
output virtualHub_VPNGateway_BGPAddresses array = virtualHub.outputs.vpnGateway_BGPAddresses
output virtualHub_VPNGateway_ASN array = virtualHub.outputs.vpnGateway_ASN


