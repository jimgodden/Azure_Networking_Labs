@description('Name of the Hub Virtual Network')
param virtualNetwork_Hub_Name string

@description('Name of the Spoke Virtual Network')
param virtualNetwork_Spoke_Name string

resource virtualNetwork_Hub 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: virtualNetwork_Hub_Name
}

resource virtualNetwork_Spoke 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: virtualNetwork_Spoke_Name
}

resource virtualNetworkPeering_Hub_to_Spoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-09-01' = {
  parent: virtualNetwork_Hub
  name: '${virtualNetwork_Hub_Name}to${virtualNetwork_Spoke_Name}'
  properties: {
    allowGatewayTransit: true
    allowForwardedTraffic: true
    useRemoteGateways: false
    allowVirtualNetworkAccess: true
    remoteVirtualNetwork: {
      id: virtualNetwork_Spoke.id
    }
  }
}

resource virtualNetworkPeering_Spoke_to_Hub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-09-01' = {
  parent: virtualNetwork_Spoke
  name: '${virtualNetwork_Spoke_Name}to${virtualNetwork_Hub_Name}'
  properties: {
    useRemoteGateways: true
    allowGatewayTransit: true
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
    remoteVirtualNetwork: {
      id: virtualNetwork_Hub.id
    }
  }
}
