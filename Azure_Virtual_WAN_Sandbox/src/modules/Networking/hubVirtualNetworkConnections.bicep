param vHubName string
param vnetName string
param vHubRouteTableDefaultID string
param vnetID string

resource vHub 'Microsoft.Network/virtualHubs@2022-11-01' existing = {
  name: vHubName
}

resource vHubVNetConn 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2022-09-01' = {
  parent: vHub
  name: '${vHubName}_to_${vnetName}'
  properties: {
    routingConfiguration: {
      associatedRouteTable: {
        id: vHubRouteTableDefaultID
      }
      propagatedRouteTables: {
        labels: [
          'default'
        ]
        ids: [
          {
            id: vHubRouteTableDefaultID
          }
        ]
      }
      vnetRoutes: {
        staticRoutes: []
        staticRoutesConfig: {
          vnetLocalRouteOverrideCriteria: 'Contains'
        }
      }
    }
    remoteVirtualNetwork: {
      id: vnetID
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
  }
}
