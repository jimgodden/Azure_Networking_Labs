@description('Name of the Source Virtual Network')
param virtualNetwork_Source_Name string

@description('Name of the Destination Virtual Network')
param virtualNetwork_Destination_Name string

resource virtualNetwork_Source 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: virtualNetwork_Source_Name
}

resource virtualNetwork_Destination 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: virtualNetwork_Destination_Name
}

resource virtualNetworkPeering_Source_to_Destination 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-09-01' = {
  parent: virtualNetwork_Source
  name: '${virtualNetwork_Source_Name}to${virtualNetwork_Destination_Name}'
  properties: {
    remoteVirtualNetwork: {
      id: virtualNetwork_Destination.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    useRemoteGateways: false
    allowGatewayTransit: false
  }
}

resource virtualNetworkPeering_Destination_to_Source 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-09-01' = {
  parent: virtualNetwork_Destination
  name: '${virtualNetwork_Destination_Name}to${virtualNetwork_Source_Name}'
  properties: {
    remoteVirtualNetwork: {
      id: virtualNetwork_Source.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    useRemoteGateways: false
    allowGatewayTransit: false
  }
}
