@description('Name of the Virtual Hub that will connect to a Virtual Network')
param virtualHub_Name string

@description('Name of the Virtual Network that will connect to a Virtual Hub')
param virtualNetwork_Name string

@description('Resource ID of the Virtual Hub\'s Default Route Table that will be applied to the Virtual Network')
param virtualHub_RouteTable_Default_ID string

@description('Resource ID of the Virtual Network that will connect to a Virtual Hub')
param virtualNetwork_ID string

resource virtualHub 'Microsoft.Network/virtualHubs@2022-11-01' existing = {
  name: virtualHub_Name
}

resource virtualHubVirtualNetworkConn 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2022-09-01' = {
  parent: virtualHub
  name: '${virtualHub_Name}_to_${virtualNetwork_Name}'
  properties: {
    routingConfiguration: {
      associatedRouteTable: {
        id: virtualHub_RouteTable_Default_ID
      }
      propagatedRouteTables: {
        labels: [
          'default'
        ]
        ids: [
          {
            id: virtualHub_RouteTable_Default_ID
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
      id: virtualNetwork_ID
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
  }
}
