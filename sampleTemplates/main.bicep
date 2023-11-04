param location string 

param virtualMachine_AdminUserName string

@secure()
param virtualMachine_AdminPassword string

param numberOfLinuxVMs int

param numberOfWindowsVMs int

// Compute

module virtualMachine_Linux '../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = [ for i in range(1, numberOfLinuxVMs): {
  name: 'linuxVM${i}'
  params: {
    acceleratedNetworking: false
    location: location
    subnet_ID: virtualNetwork_SpokeA.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUserName: virtualMachine_AdminUserName
    virtualMachine_Name: 'linuxVM${i}'
    virtualMachine_Size: 'B2ms'
  }
} ]

module virtualMachine_Windows '../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = [ for i in range(1, numberOfWindowsVMs): {
  name: 'windowsVM${i}'
  params: {
    acceleratedNetworking: false
    location: location
    subnet_ID: virtualNetwork_SpokeA.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUserName: virtualMachine_AdminUserName
    virtualMachine_Name: 'windowsVM${i}'
    virtualMachine_Size: 'B2ms'
  }
} ]

// Network

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
    applicationGateway_SubnetID: virtualNetwork_SpokeA.outputs.applicationGatewaySubnetID
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
    bastion_Subnet_ID: virtualNetwork_Hub.outputs.bastion_SubnetID
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
