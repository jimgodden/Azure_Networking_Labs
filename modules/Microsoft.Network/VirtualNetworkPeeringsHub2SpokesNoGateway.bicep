@description('Resource Id of the Hub Virtual Network')
param virtualNetwork_Hub_Id string

@description('Array of Resource Ids of the Spoke Virtual Networks')
param virtualNetwork_Spoke_Ids array

resource virtualNetworkPeering_Hub_to_Spoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = [for virtualNetwork_Spoke_Id in virtualNetwork_Spoke_Ids: {
  name: '${split(virtualNetwork_Hub_Id, '/')[8]}/to${split(virtualNetwork_Spoke_Id, '/')[8]}'
  properties: {
    remoteVirtualNetwork: {
      id: virtualNetwork_Spoke_Id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    useRemoteGateways: false
    allowGatewayTransit: true
  }
} ]

resource virtualNetworkPeering_Spokes_to_Hub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = [for virtualNetwork_Spoke_Id in virtualNetwork_Spoke_Ids:  {
  name: '${split(virtualNetwork_Spoke_Id, '/')[8]}/to${split(virtualNetwork_Hub_Id, '/')[8]}'
  properties: {
    remoteVirtualNetwork: {
      id: virtualNetwork_Hub_Id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    useRemoteGateways: false
    allowGatewayTransit: false
  }
} ]
