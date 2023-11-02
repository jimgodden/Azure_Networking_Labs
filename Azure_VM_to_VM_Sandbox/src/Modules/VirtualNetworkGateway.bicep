@description('Azure Datacenter that the resources are deployed to')
param location string

@description('Name of the Azure Virtual Network Gateway')
param VNG_Name string

@description('SKU of the Virtual Network Gateway')
param VNG_SKU string = 'VpnGw1'

@description('Virtul Network Gateway ASN for BGP')
param VNG_ASN int
 
@description('Virtual Network Resource ID')
param VNG_Subnet_ResourceID string

resource VNG_PIP 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: '${VNG_Name}_PIP'
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

resource VNG 'Microsoft.Network/virtualNetworkGateways@2023-02-01' = {
  name: VNG_Name
  location: location
  properties: {
    enablePrivateIpAddress: false
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: VNG_PIP.id
          }
          subnet: {
            id: VNG_Subnet_ResourceID
          }
        }
      }
    ]
    natRules: []
    virtualNetworkGatewayPolicyGroups: []
    enableBgpRouteTranslationForNat: false
    disableIPSecReplayProtection: false
    sku: {
      name: VNG_SKU
      tier: VNG_SKU
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: true
    activeActive: false
    bgpSettings: {
      asn: VNG_ASN
      peerWeight: 0
    }
    vpnGatewayGeneration: 'Generation1'
    allowRemoteVnetTraffic: false
    allowVirtualWanTraffic: false
  }
}

output VNGResourceID string = VNG.id
output VNGName string = VNG.name
output VNGPIP string = VNG_PIP.properties.ipAddress
output VNGBGPAddress string = VNG.properties.bgpSettings.bgpPeeringAddress
output VNGASN int = VNG.properties.bgpSettings.asn

