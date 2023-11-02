@description('Azure Datacenter that the resources are deployed to')
param location string

@description('Unique prefix to the names of each resource (i.e. src to dst)')
param resourceNamePrefix string

@description('Public IP Address of the VPN Gateway Instance')
param gatewayIPAddress string

@description('BGP Peering Address of the VPN Gateway Instance')
param bgpPeeringAddress string

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

@description('Existing Virtual Network Gateway ID')
param VNGResourceID string

@description('ASN of the Destination VPN')
param destination_ASN int

resource connection 'Microsoft.Network/connections@2022-11-01' = {
    name: '${resourceNamePrefix}_conn'
    location: location
    properties: {
      virtualNetworkGateway1: {
        id: VNGResourceID
        properties: {
          
        }
      }
      localNetworkGateway2: {
        id: lng.id
        properties: {
          
        }
      }
      connectionType: 'IPsec'
      connectionProtocol: 'IKEv2'
      routingWeight: 0
      sharedKey: vpn_SharedKey
      enableBgp: true
      useLocalAzureIpAddress: false 
      usePolicyBasedTrafficSelectors: false
    //                      Default is used with the following commented out
    // ipsecPolicies: [
    //   {
    //     saLifeTimeSeconds: 3600
    //     saDataSizeKilobytes: 102400000
    //     ipsecEncryption: 'AES256'
    //     ipsecIntegrity: 'SHA256'
    //     ikeEncryption: 'AES256'
    //     ikeIntegrity: 'SHA256'
    //     dhGroup: 'DHGroup14'
    //     pfsGroup: 'None'
    //   }
    // ]
      dpdTimeoutSeconds: 45
      connectionMode: 'Default'
  }
}

resource lng 'Microsoft.Network/localNetworkGateways@2022-11-01' = {
  name: '${resourceNamePrefix}_lng'
  location: location
  properties: {
    gatewayIpAddress: gatewayIPAddress
    bgpSettings: {
      asn: destination_ASN
      bgpPeeringAddress: bgpPeeringAddress
    }
  }
}

