@description('Azure Datacenter that the resources are deployed to')
param location string

@description('Name of the ExpressRoute Circuit')
param expressRouteCircuit_Name string

@description('Service Provider name for the ExpressRoute Circuit')
param serviceProviderName string = 'Megaport'

@description('Peering Location for the ExpressRoute Circuit')
param peeringLocation string = 'Dallas'

@description('Bandwidth in Mbps for the ExpressRoute Circuit')
@allowed([
  50
  100
  200
  500
  1000
  2000
  5000
  10000
])
param bandwidthInMbps int = 50

@allowed([
  'Standard'
  'Premium'
])
@description('SKU Tier of the ExpressRoute Circuit')
param skuTier string = 'Standard'

@allowed([
  'MeteredData'
  'UnlimitedData'
])
@description('SKU Family of the ExpressRoute Circuit')
param skuFamily string = 'MeteredData'

@description('Enable Private Peering')
param enablePrivatePeering bool = true

@description('VLAN ID for Private Peering (100-4094)')
param privatePeeringVlanId int = 100

@description('Primary peer subnet for Private Peering (e.g., 192.168.1.0/30)')
param privatePeeringPrimarySubnet string = '192.168.1.0/30'

@description('Secondary peer subnet for Private Peering (e.g., 192.168.1.4/30)')
param privatePeeringSecondarySubnet string = '192.168.1.4/30'

@description('Peer ASN for Private Peering')
param privatePeeringPeerASN int = 65001

param tagValues object = {}

resource expressRouteCircuit 'Microsoft.Network/expressRouteCircuits@2023-04-01' = {
  name: expressRouteCircuit_Name
  location: location
  sku: {
    name: '${skuTier}_${skuFamily}'
    tier: skuTier
    family: skuFamily
  }
  properties: {
    serviceProviderProperties: {
      serviceProviderName: serviceProviderName
      peeringLocation: peeringLocation
      bandwidthInMbps: bandwidthInMbps
    }
    allowClassicOperations: false
  }
  tags: tagValues
}

resource privatePeering 'Microsoft.Network/expressRouteCircuits/peerings@2023-04-01' = if (enablePrivatePeering) {
  parent: expressRouteCircuit
  name: 'AzurePrivatePeering'
  properties: {
    peeringType: 'AzurePrivatePeering'
    peerASN: privatePeeringPeerASN
    primaryPeerAddressPrefix: privatePeeringPrimarySubnet
    secondaryPeerAddressPrefix: privatePeeringSecondarySubnet
    vlanId: privatePeeringVlanId
    state: 'Enabled'
  }
}

output expressRouteCircuit_Name string = expressRouteCircuit.name
output expressRouteCircuit_ID string = expressRouteCircuit.id
output expressRouteCircuit_ServiceKey string = expressRouteCircuit.properties.serviceKey
output expressRouteCircuit_ServiceProviderProvisioningState string = expressRouteCircuit.properties.serviceProviderProvisioningState
