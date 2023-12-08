param routeTable_Name string

param routeTableRoute_Name string

param addressPrefixs array

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

resource routeTable_Route_Firewall 'Microsoft.Network/routeTables/routes@2023-05-01' = [for i in range(0, length(addressPrefixs)):  if (nextHopType == 'VirtualAppliance') {
  parent: routeTable
  name: '${routeTableRoute_Name}${i}'
  properties: {
    addressPrefix: addressPrefixs[i]
    nextHopType: nextHopType
    nextHopIpAddress: nextHopIpAddress
  }
} ]

resource routeTable_Route 'Microsoft.Network/routeTables/routes@2023-05-01' = [for i in range(0, length(addressPrefixs)):  if (nextHopType != 'VirtualAppliance') {
  parent: routeTable
  name: '${routeTableRoute_Name}${i}'
  properties: {
    addressPrefix: addressPrefixs[i]
    nextHopType: nextHopType
  }
} ]
