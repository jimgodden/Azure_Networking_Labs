@description('Name of the First Virtual Network')
param virtualNetwork1_Id string

@description('Name of the Second Virtual Network')
param virtualNetwork2_Id string

var virtualNetwork1_Name = split(virtualNetwork1_Id, '/')[8]
var virtualNetwork2_Name = split(virtualNetwork2_Id, '/')[8]

resource virtualNetworkPeering_1_to_2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-09-01' = {
  name: '${virtualNetwork1_Name}/to${virtualNetwork2_Name}'
  properties: {
    remoteVirtualNetwork: {
      id: virtualNetwork2_Id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    useRemoteGateways: false
    allowGatewayTransit: false
  }
}

resource virtualNetworkPeering_2_to_1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-09-01' = {
  name: '${virtualNetwork2_Name}/to${virtualNetwork1_Name}'
  properties: {
    remoteVirtualNetwork: {
      id: virtualNetwork1_Id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    useRemoteGateways: false
    allowGatewayTransit: false
  }
}
