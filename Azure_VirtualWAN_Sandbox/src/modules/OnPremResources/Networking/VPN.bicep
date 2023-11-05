@description('Azure Datacenter that the resources are deployed to')
param location string

@description('Name of the Azure Virtual Network Gateway in vHub A')
param OnPrem_VNG_Name string

@description('OnPrem VPN ASN')
param OnPrem_VNG_ASN int

@description('Virtual Network Resource ID')
param OnPrem_VNG_Subnet_ResourceID string

resource OnPrem_VNG_PIP 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: '${OnPrem_VNG_Name}_PIP'
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

resource OnPrem_VNG 'Microsoft.Network/virtualNetworkGateways@2023-02-01' = {
  name: OnPrem_VNG_Name
  location: location
  properties: {
    enablePrivateIpAddress: false
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: OnPrem_VNG_PIP.id
          }
          subnet: {
            id: OnPrem_VNG_Subnet_ResourceID
          }
        }
      }
    ]
    natRules: []
    virtualNetworkGatewayPolicyGroups: []
    enableBgpRouteTranslationForNat: false
    disableIPSecReplayProtection: false
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: true
    activeActive: false
    bgpSettings: {
      asn: OnPrem_VNG_ASN
      peerWeight: 0
    }
    vpnGatewayGeneration: 'Generation1'
    allowRemoteVnetTraffic: false
    allowVirtualWanTraffic: false
  }
}

output onpremVNGResourceID string = OnPrem_VNG.id
output onpremVNGName string = OnPrem_VNG.name
output onpremVNGPIP string = OnPrem_VNG_PIP.properties.ipAddress
output onPremVNGBGPAddress string = OnPrem_VNG.properties.bgpSettings.bgpPeeringAddress
output onpremVNGASN int = OnPrem_VNG.properties.bgpSettings.asn

