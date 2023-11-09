param location string 

param virtualMachine_AdminUsername string

@secure()
param virtualMachine_AdminPassword string

param numberOfLinuxVMs int

param numberOfWindowsVMs int

// Start Compute

module virtualMachine_Linux '../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = [ for i in range(1, numberOfLinuxVMs): {
  name: 'linuxVM${i}'
  params: {
    acceleratedNetworking: false
    location: location
    subnet_ID: virtualNetwork_SpokeA.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'linuxVM${i}'
    virtualMachine_Size: 'B2ms'
    virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'
    virtualMachine_ScriptFileName: 'Ubuntu20_DNS_Config.sh'
  }
} ]

module virtualMachine_Windows '../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = [ for i in range(1, numberOfWindowsVMs): {
  name: 'windowsVM${i}'
  params: {
    acceleratedNetworking: false
    location: location
    subnet_ID: virtualNetwork_SpokeA.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'windowsVM${i}'
    virtualMachine_Size: 'B2ms'
    virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'
    virtualMachine_ScriptFileName: 'WinServ2022_General_InitScript.ps1'
  }
} ]

// End Compute

// Start Network

module virtualNetwork_Hub '../modules/Microsoft.Network/VirtualNetworkHub.bicep' = {
  name: 'hubVNet'
  params: {
    firstTwoOctetsOfVirtualNetworkPrefix: '10.0'
    location: location
    networkSecurityGroup_Default_Name: 'general_nsg'
    routeTable_Name: 'general_rt'
    virtualNetwork_Name: 'hub_VNet'
  }
}

module virtualNetwork_SpokeA '../modules/Microsoft.Network/VirtualNetworkSpoke.bicep' = {
  name: 'spokeAVNet'
  params: {
    firstTwoOctetsOfVirtualNetworkPrefix: '10.1'
    location: location
    networkSecurityGroup_Default_Name: 'general_nsg_spokeA'
    routeTable_Name: 'general_rt_spokeA'
    virtualNetwork_Name: 'spokeA_VNet'
  }
}

module virtualNetworkPeering_SpokeA_to_Hub '../modules/Microsoft.Network/VirtualNetworkPeering.bicep' = {
  name: 'spokeA_to_hub'
  params: {
    virtualNetwork_Destination_Name: virtualNetwork_Hub.outputs.virtualNetwork_Name
    virtualNetwork_Source_Name: virtualNetwork_SpokeA.outputs.virtualNetwork_Name
  }
}

module virtualNetworkPeering_Hub_to_SpokeA '../modules/Microsoft.Network/VirtualNetworkPeering.bicep' = {
  name: 'hub_to_spokeA'
  params: {
    virtualNetwork_Destination_Name: virtualNetwork_Hub.outputs.virtualNetwork_Name
    virtualNetwork_Source_Name: virtualNetwork_SpokeA.outputs.virtualNetwork_Name
  }
}

module applicationGateway '../modules/Microsoft.Network/ApplicationGateway_v2.bicep' = {
  name: 'applicationGateway'
  params: {
    applicationGateway_Name: 'applicationGateway'
    applicationGateway_PrivateIP_Address: virtualNetwork_SpokeA.outputs.applicationGateway_PrivateIP
    applicationGateway_SubnetID: virtualNetwork_SpokeA.outputs.applicationGateway_SubnetID
    applicationGatewayWAF_Name: 'applicationGatewayWAF'
    backendPoolFQDN: 'www.example.com'
    location: location
    publicIP_ApplicationGateway_Name: 'applicationGatewayPIP'
  }
}

module azureFirewall '../modules/Microsoft.Network/AzureFirewall.bicep' = {
  name: 'AzFW'
  params: {
    azureFirewall_ManagementSubnet_ID: virtualNetwork_Hub.outputs.azureFirewallManagement_SubnetID
    azureFirewall_Name: 'AzFW'
    azureFirewall_SKU: 'Basic'
    azureFirewall_Subnet_ID: virtualNetwork_Hub.outputs.azureFirewall_SubnetID
    azureFirewallPolicy_Name: 'AzFWPolicy'
    location: location
  }
}

module bastion '../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_SubnetID: virtualNetwork_Hub.outputs.bastion_SubnetID
    location: location
  }
}

module privateLink '../modules/Microsoft.Network/PrivateLink.bicep' = {
  name: 'privateLink'
  params: {
    internalLoadBalancer_SubnetID: virtualNetwork_SpokeA.outputs.general_SubnetID
    location: location
    // [0] is used to get the first VM in the array.  This isn't necessary for a normal deployment since only 1 VM will be deployed
    networkInterface_IPConfig_Name: virtualMachine_Windows[0].outputs.networkInterface_IPConfig0_Name
    networkInterface_Name: virtualMachine_Windows[0].outputs.networkInterface_Name
    networkInterface_SubnetID: virtualNetwork_SpokeA.outputs.general_SubnetID
    privateEndpoint_SubnetID: virtualNetwork_SpokeA.outputs.privateEndpoint_SubnetID
    privateLink_SubnetID: virtualNetwork_SpokeA.outputs.privateLinkService_SubnetID
  }
}

//
// The following modules should be used in conjuction when creating a Virtual WAN
//
module virtualWAN '../modules/Microsoft.Network/VirtualWAN.bicep' = {
  name: 'virtualWAN'
  params: {
    location: location
    virtualWAN_Name: 'vwan'
  }
}

module virtualHubA '../modules/Microsoft.Network/VirtualHub.bicep' = {
  name: 'vhubA'
  params: {
    location: location
    virtualHub_AddressPrefix: '10.100.0.0/16'
    virtualHub_Name: 'vhubA'
    virtualWAN_ID: virtualWAN.outputs.virtualWAN_ID
    usingAzureFirewall: true
    azureFirewall_SKU: 'Basic'
    usingVPN: true
  }
}

module virtualHubAToVirtualNetworkSpokeAConn '../modules/Microsoft.Network/hubVirtualNetworkConnections.bicep' = {
  name: 'vhubA_to_spokeA_Conn'
  params: {
    virtualHub_Name: virtualHubA.outputs.virtualHub_Name
    virtualHub_RouteTable_Default_ID: virtualHubA.outputs.virtualHub_RouteTable_Default_ID
    virtualNetwork_ID: virtualNetwork_SpokeA.outputs.virtualNetwork_ID
    virtualNetwork_Name: virtualNetwork_SpokeA.outputs.virtualNetwork_Name
  }
}
//
// End Virtual WAN required resources
//

module virtualNetworkGateway '../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'virtualNetworkGateway'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65000
    virtualNetworkGateway_Name: 'vng'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork_Hub.outputs.gateway_SubnetID
  }
}

module virtualNetworkGatewayConnection '../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'vng_to_destination'
  params: {
    location: location 
    virtualNetworkGateway_ID: virtualNetworkGateway.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_ASN: 65001
    vpn_Destination_BGPIPAddress: '10.0.0.1'
    vpn_Destination_Name: 'Home'
    vpn_Destination_PublicIPAddress: '1.2.3.4'
    vpn_SharedKey: '99999999'
  }
}

// End Networking

// Start Storage

module storageAccount '../modules/Microsoft.Storage/StorageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    location: location
    privateDNSZoneLinkedVnetIDList: [virtualNetwork_Hub.outputs.virtualNetwork_ID, virtualNetwork_SpokeA.outputs.virtualNetwork_ID]
    privateDNSZoneLinkedVnetNamesList: [virtualNetwork_Hub.outputs.virtualNetwork_Name, virtualNetwork_SpokeA.outputs.virtualNetwork_Name]
    privateEndpoint_VirtualNetwork_Name: [virtualNetwork_SpokeA.outputs.virtualNetwork_Name]
    privateEndpoints_Blob_Name: 'storageAccount_Name_Blob_PE'
    privateEndpoint_SubnetID: [virtualNetwork_SpokeA.outputs.privateEndpoint_SubnetID]
    storageAccount_Name: 'readdescfornamingreq'
    privateEndpoints_File_Name: 'storageAccount_Name_File_PE'
  }
}

// End Storage

// Start Web

module webApp '../modules/Microsoft.Web/site.bicep' = {
  name: 'webApp'
  params: {
    appServiceSubnet_ID: virtualNetwork_SpokeA.outputs.appService_SubnetID
    appServicePlan_Name: 'asp'
    location: location
    virtualNetwork_Name: virtualNetwork_SpokeA.outputs.virtualNetwork_Name
    site_Name: 'readdescfornamingreq'
  }
}

