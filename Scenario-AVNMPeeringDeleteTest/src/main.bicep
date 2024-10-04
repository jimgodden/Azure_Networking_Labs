param location string = resourceGroup().location

// Virtual Networks
module virtualNetworkA '../../Modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnetA'
  params: {
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    location: location
    virtualNetwork_Name: 'vnetA'
  }
}

module virtualNetworkB '../../Modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnetB'
  params: {
    virtualNetwork_AddressPrefix: '10.2.0.0/16'
    location: location
    virtualNetwork_Name: 'vnetB'
  }
}

module virtualNetworkC '../../Modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnetC'
  params: {
    virtualNetwork_AddressPrefix: '10.3.0.0/16'
    location: location
    virtualNetwork_Name: 'vnetC'
  }
}

module virtualNetworkHub '../../Modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnetHub'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: location
    virtualNetwork_Name: 'vnetHub'
  }
}

module virtualNetworkGateway_Hub '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'HubVirtualNetworkGateway'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65001
    virtualNetworkGateway_Name: 'Hub_VNG'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetworkHub.outputs.gateway_SubnetID
  }
}

module hub_to_A_peer '../../modules/Microsoft.Network/VirtualNetworkPeeringHub2Spoke.bicep' = {
  name: 'hub_to_A_peer'
  params: {
    virtualNetwork_Spoke_Name: virtualNetworkA.outputs.virtualNetwork_Name
    virtualNetwork_Hub_Name: virtualNetworkHub.outputs.virtualNetwork_Name
  }
  dependsOn: [
    virtualNetworkGateway_Hub
  ]
}

module hub_to_B_peer '../../modules/Microsoft.Network/VirtualNetworkPeeringHub2Spoke.bicep' = {
  name: 'hub_to_B_peer'
  params: {
    virtualNetwork_Spoke_Name: virtualNetworkB.outputs.virtualNetwork_Name
    virtualNetwork_Hub_Name: virtualNetworkHub.outputs.virtualNetwork_Name
  }
  dependsOn: [
    virtualNetworkGateway_Hub
  ]
}
