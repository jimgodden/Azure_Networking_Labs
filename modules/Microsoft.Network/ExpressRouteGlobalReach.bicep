@description('Name of the first ExpressRoute Circuit')
param expressRouteCircuit_Name string

@description('Resource ID of the peered ExpressRoute Circuit')
param peer_ExpressRouteCircuit_ID string

@description('/29 subnet for the Global Reach connection primary link')
param globalReachPrimarySubnet string = '172.16.0.0/29'

resource expressRouteCircuit 'Microsoft.Network/expressRouteCircuits@2023-04-01' existing = {
  name: expressRouteCircuit_Name
}

resource privatePeering 'Microsoft.Network/expressRouteCircuits/peerings@2023-04-01' existing = {
  parent: expressRouteCircuit
  name: 'AzurePrivatePeering'
}

resource globalReachConnection 'Microsoft.Network/expressRouteCircuits/peerings/connections@2023-04-01' = {
  parent: privatePeering
  name: 'GlobalReach_Connection'
  properties: {
    expressRouteCircuitPeering: {
      id: privatePeering.id
    }
    peerExpressRouteCircuitPeering: {
      id: '${peer_ExpressRouteCircuit_ID}/peerings/AzurePrivatePeering'
    }
    addressPrefix: globalReachPrimarySubnet
  }
}

output globalReachConnection_ID string = globalReachConnection.id
output globalReachConnection_Name string = globalReachConnection.name
