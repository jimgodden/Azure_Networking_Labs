@description('Name of the First Virtual Network')
param virtualNetwork1_Name string

@description('Name of the Second Virtual Network')
param virtualNetwork2_Name string

resource virtualNetwork1 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: virtualNetwork1_Name
}

resource virtualNetwork2 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: virtualNetwork2_Name
}

resource virtualNetworkPeering_1_to_2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-09-01' = {
  parent: virtualNetwork1
  name: '${virtualNetwork1_Name}to${virtualNetwork2_Name}'
  properties: {
    remoteVirtualNetwork: {
      id: virtualNetwork2.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    useRemoteGateways: false
    allowGatewayTransit: false
  }
}

resource virtualNetworkPeering_2_to_1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-09-01' = {
  parent: virtualNetwork2
  name: '${virtualNetwork2_Name}to${virtualNetwork1_Name}'
  properties: {
    remoteVirtualNetwork: {
      id: virtualNetwork1.id
    }
  }
}
