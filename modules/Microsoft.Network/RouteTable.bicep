param routeTable_Name string

param routeTableRoute_Name string

param addressPrefix string

param nextHopIpAddress string = ''


@allowed([
  'None'
  'VirtualAppliance' 
  'Internet'
  'VirtualNetworkGateway'
  'VnetLocal'
])
param nextHopType string

resource routeTable 'Microsoft.Network/routeTables@2023-02-01' existing = {
  name: routeTable_Name
}

resource routeTable_Route_Firewall 'Microsoft.Network/routeTables/routes@2023-05-01' = if (nextHopType == 'VirtualAppliance') {
  parent: routeTable
  name: routeTableRoute_Name
  properties: {
    addressPrefix: addressPrefix
    nextHopType: nextHopType
    nextHopIpAddress: nextHopIpAddress
  }
}

resource routeTable_Route 'Microsoft.Network/routeTables/routes@2023-05-01' = if (nextHopType != 'VirtualAppliance') {
  parent: routeTable
  name: routeTableRoute_Name
  properties: {
    addressPrefix: addressPrefix
    nextHopType: nextHopType
  }
}
