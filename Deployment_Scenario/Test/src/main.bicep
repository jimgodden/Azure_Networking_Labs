@description('Azure Datacenter location for the Hub and Spoke A resources')
var location = resourceGroup().location

resource networkSecurityGroup_Generic 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'genericNSG'
  location: location
}

resource virtualNetwork_Hub 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'hub_VNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'General'
        properties: {
          addressPrefix: '10.0.0.0/24'
          routeTable: {
            id: routeTable_Hub.id
          }
          networkSecurityGroup: {
            id: networkSecurityGroup_Generic.id
          }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          routeTable: {
            id: routeTable_Hub.id
          }
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
        }
      }
    ]
  }
}

resource routeTable_Hub 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'hub_RouteTable'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'toSpokeA'
        properties: {
          addressPrefix: '10.1.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
      {
        name: 'toSpokeB'
        properties: {
          addressPrefix: '10.2.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
    ]
  }
}


resource virtualNetwork_SpokeA 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'spokeA_VNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'General'
        properties: {
          addressPrefix: '10.1.0.0/24'
          routeTable: {
            id: routeTable_Spokes.id
          }
          networkSecurityGroup: {
            id: networkSecurityGroup_Generic.id
          }
        }
      }
    ]
  }
}

resource virtualNetwork_SpokeB 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'spokeB_VNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.2.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'General'
        properties: {
          addressPrefix: '10.2.0.0/24'
          routeTable: {
            id: routeTable_Spokes.id
          }
          networkSecurityGroup: {
            id: networkSecurityGroup_Generic.id
          }
        }
      }
      {
        name: 'PrivateEndpoint'
        properties: {
          addressPrefix: '10.2.1.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup_Generic.id
          }
        }
      }
    ]
  }
}

resource routeTable_Spokes 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'spoke_RouteTable'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'toHub'
        properties: {
          addressPrefix: '10.1.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
      {
        name: 'toTenSlashEight'
        properties: {
          addressPrefix: '10.0.0.0/8'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
    ]
  }
}

module peerings_Hub_to_Spokes '../../../modules/Microsoft.Network/VirtualNetworkPeeringsHub2Spokes.bicep' = {
  name: 'peerings_Hub_to_Spokes'
  params: {
    virtualNetwork_Hub_Id: virtualNetwork_Hub.id
    virtualNetwork_Spoke_Ids: [
      virtualNetwork_SpokeA.id
      virtualNetwork_SpokeB.id
    ]
  }
}
