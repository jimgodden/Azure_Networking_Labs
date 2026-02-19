@description('Azure Datacenter that the resources are deployed to')
param location string

@description('Name of the ExpressRoute Connection')
param connection_Name string

@description('Resource ID of the ExpressRoute Gateway')
param expressRouteGateway_ID string

@description('Resource ID of the ExpressRoute Circuit')
param expressRouteCircuit_ID string

@description('Connection routing weight')
param routingWeight int = 0

@description('Enable FastPath for connection (requires UltraPerformance or ErGw3AZ SKU)')
param enableFastPath bool = false

@description('Authorization Key for the connection (optional - used when circuit is in different subscription)')
param authorizationKey string = ''

param tagValues object = {}

resource expressRouteConnection 'Microsoft.Network/connections@2023-04-01' = {
  name: connection_Name
  location: location
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: expressRouteGateway_ID
      properties: {}
    }
    peer: {
      id: expressRouteCircuit_ID
    }
    routingWeight: routingWeight
    enableBgp: false
    expressRouteGatewayBypass: enableFastPath
    authorizationKey: !empty(authorizationKey) ? authorizationKey : null
  }
  tags: tagValues
}

output connection_Name string = expressRouteConnection.name
output connection_ID string = expressRouteConnection.id
output connection_ProvisioningState string = expressRouteConnection.properties.provisioningState
