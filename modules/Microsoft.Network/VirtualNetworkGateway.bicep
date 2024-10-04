@description('Azure Datacenter that the resources are deployed to')
param location string

@description('Name of the Azure Virtual Network Gateway')
param virtualNetworkGateway_Name string

@allowed([
  'Basic'
  'VpnGw1'
  'VpnGw2'
  'VpnGw3'
  'VpnGw4'
  'VpnGw5'
  'VpnGw1AZ'
  'VpnGw2AZ'
  'VpnGw3AZ'
  'VpnGw4AZ'
  'VpnGw5AZ'
])
@description('SKU of the Virtual Network Gateway')
param virtualNetworkGateway_SKU string = 'VpnGw1'

@allowed([
  'Generation1'
  'Generation2'
])
@description('''Generation of the Virtual Network Gateway SKU
Generation1: Basic, VpnGw1-3, VpnGw1-3AZ
Generation2: VpnGw2-5, VpnGw2-5Az''')
param vpnGatewayGeneration string = 'Generation1'

@description('Virtul Network Gateway ASN for BGP')
param virtualNetworkGateway_ASN int
 
@description('Virtual Network Resource ID')
param virtualNetworkGateway_Subnet_ResourceID string

@description('Configures the Virtual Network Gateway as Active Active with two Public IP Addresses if True.  Default is False.')
param activeActive bool = false

param tagValues object = {}

// Potential Virtual Network Gateway configurations (active-active vs active-passive)
var ipConfiguration = activeActive ? [
  {
    name: 'vNetGatewayConfig1'
    properties: {
      privateIPAllocationMethod: 'Dynamic'
      subnet: {
        id: virtualNetworkGateway_Subnet_ResourceID
      }
      publicIPAddress: {
        id: virtualNetworkGateway_PublicIPAddress01.id
      }
    }
  }
  {
    properties: {
      name: 'vNetGatewayConfig2'
      privateIPAllocationMethod: 'Dynamic'
      subnet: {
        id: virtualNetworkGateway_Subnet_ResourceID
      }
      publicIPAddress: {
        id: virtualNetworkGateway_PublicIPAddress02.id
      }
    }
  } ]
: [
  {
    name: 'vNetGatewayConfig1'
    properties: {
      privateIPAllocationMethod: 'Dynamic'
      subnet: {
        id: virtualNetworkGateway_Subnet_ResourceID
      }
      publicIPAddress: {
        id: virtualNetworkGateway_PublicIPAddress01.id
      }
    }
  }
]

resource virtualNetworkGateway_PublicIPAddress01 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: '${virtualNetworkGateway_Name}_PIP_01'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    ipTags: []
  }
  tags: tagValues
}

resource virtualNetworkGateway_PublicIPAddress02 'Microsoft.Network/publicIPAddresses@2022-11-01' = if (activeActive) {
  name: '${virtualNetworkGateway_Name}_PIP_02'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    ipTags: []
  }
  tags: tagValues
}

resource virtualNetworkGateway 'Microsoft.Network/virtualNetworkGateways@2023-02-01' = {
  name: virtualNetworkGateway_Name
  location: location
  properties: {
    enablePrivateIpAddress: false
    ipConfigurations: ipConfiguration
    natRules: []
    virtualNetworkGatewayPolicyGroups: []
    enableBgpRouteTranslationForNat: false
    disableIPSecReplayProtection: false
    sku: {
      name: virtualNetworkGateway_SKU
      tier: virtualNetworkGateway_SKU
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: true
    activeActive: activeActive
    bgpSettings: {
      asn: virtualNetworkGateway_ASN
      peerWeight: 0
    }
    vpnGatewayGeneration: vpnGatewayGeneration
    allowRemoteVnetTraffic: false
    allowVirtualWanTraffic: false
  }
  tags: tagValues
}

output virtualNetworkGateway_ResourceID string = virtualNetworkGateway.id
output virtualNetworkGateway_Name string = virtualNetworkGateway.name
output virtualNetworkGateway_BGPAddress string = virtualNetworkGateway.properties.bgpSettings.bgpPeeringAddress
output virtualNetworkGateway_ActiveActive_BGPAddress1 string = activeActive ? virtualNetworkGateway.properties.bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0] : ''
output virtualNetworkGateway_ActiveActive_BGPAddress2 string = activeActive ? virtualNetworkGateway.properties.bgpSettings.bgpPeeringAddresses[1].defaultBgpIpAddresses[0] : ''

output virtualNetworkGateway_ASN int = virtualNetworkGateway.properties.bgpSettings.asn

output virtualNetworkGateway_PublicIPAddress string = virtualNetworkGateway_PublicIPAddress01.properties.ipAddress
output virtualNetworkGateway_ActiveActive_PublicIPAddress02 string = activeActive ? virtualNetworkGateway_PublicIPAddress02.properties.ipAddress : '' 
