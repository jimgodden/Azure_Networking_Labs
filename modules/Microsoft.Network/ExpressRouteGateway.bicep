@description('Azure Datacenter that the resources are deployed to')
param location string

@description('Name of the ExpressRoute Gateway')
param expressRouteGateway_Name string

@allowed([
  'Standard'
  'HighPerformance'
  'UltraPerformance'
  'ErGw1AZ'
  'ErGw2AZ'
  'ErGw3AZ'
])
@description('SKU of the ExpressRoute Gateway')
param expressRouteGateway_SKU string = 'Standard'

@description('Resource ID of the GatewaySubnet')
param gatewaySubnet_ID string

@description('Allow traffic from remote VNets through this gateway')
param allowRemoteVnetTraffic bool = false

param tagValues object = {}

resource expressRouteGateway_PublicIPAddress 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${expressRouteGateway_Name}_PIP'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: contains(expressRouteGateway_SKU, 'AZ') ? ['1', '2', '3'] : []
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
  tags: tagValues
}

resource expressRouteGateway 'Microsoft.Network/virtualNetworkGateways@2023-04-01' = {
  name: expressRouteGateway_Name
  location: location
  properties: {
    gatewayType: 'ExpressRoute'
    sku: {
      name: expressRouteGateway_SKU
      tier: expressRouteGateway_SKU
    }
    allowRemoteVnetTraffic: allowRemoteVnetTraffic
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: expressRouteGateway_PublicIPAddress.id
          }
          subnet: {
            id: gatewaySubnet_ID
          }
        }
      }
    ]
  }
  tags: tagValues
}

output expressRouteGateway_Name string = expressRouteGateway.name
output expressRouteGateway_ID string = expressRouteGateway.id
output expressRouteGateway_PublicIPAddress string = expressRouteGateway_PublicIPAddress.properties.ipAddress
