@description('Azure Datacenter that the resources are deployed to')
param location string

@description('Name of the Azure Virtual Network Gateway')
param virtualNetworkGateway_Name string

@description('SKU of the Virtual Network Gateway')
param virtualNetworkGateway_SKU string = 'VpnGw1'

@description('Virtul Network Gateway ASN for BGP')
param virtualNetworkGateway_ASN int
 
@description('Virtual Network Resource ID')
param virtualNetworkGateway_Subnet_ResourceID string

resource virtualNetworkGateway_PublicIPAddress 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: '${virtualNetworkGateway_Name}_PIP'
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
}

resource virtualNetworkGateway 'Microsoft.Network/virtualNetworkGateways@2023-02-01' = {
  name: virtualNetworkGateway_Name
  location: location
  properties: {
    enablePrivateIpAddress: false
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: virtualNetworkGateway_PublicIPAddress.id
          }
          subnet: {
            id: virtualNetworkGateway_Subnet_ResourceID
          }
        }
      }
    ]
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
    activeActive: false
    bgpSettings: {
      asn: virtualNetworkGateway_ASN
      peerWeight: 0
    }
    vpnGatewayGeneration: 'Generation1'
    allowRemoteVnetTraffic: false
    allowVirtualWanTraffic: false
  }
}

output virtualNetworkGateway_ResourceID string = virtualNetworkGateway.id
output virtualNetworkGateway_Name string = virtualNetworkGateway.name
output virtualNetworkGateway_PublicIPAddress string = virtualNetworkGateway_PublicIPAddress.properties.ipAddress
output virtualNetworkGateway_BGPAddress string = virtualNetworkGateway.properties.bgpSettings.bgpPeeringAddress
output virtualNetworkGateway_ASN int = virtualNetworkGateway.properties.bgpSettings.asn





















