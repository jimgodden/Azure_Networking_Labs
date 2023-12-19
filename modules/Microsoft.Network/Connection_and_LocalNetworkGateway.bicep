@description('Azure Datacenter to which the resources will be deployed')
param location string

@description('Friendly name for the destination VPN device')
param vpn_Destination_Name string

@description('Public IP Address of the Destination VPN')
param vpn_Destination_PublicIPAddress string

@description('BGP Peering Address of the Destination VPN')
param vpn_Destination_BGPIPAddress string

@description('ASN of the Destination VPN')
param vpn_Destination_ASN int

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

@description('Existing Virtual Network Gateway ID')
param virtualNetworkGateway_ID string

var virtualNetworkGateway_ID_Split = split(virtualNetworkGateway_ID, '/')
var virtualNetworkGateway_Name = virtualNetworkGateway_ID_Split[8]  // Needs to be tested.  Might be 7 instead.

resource connection 'Microsoft.Network/connections@2022-11-01' = {
    name: '${virtualNetworkGateway_Name}_to_${vpn_Destination_Name}_Connection'
    location: location
    properties: {
      virtualNetworkGateway1: {
        id: virtualNetworkGateway_ID
        properties: {
          
        }
      }
      localNetworkGateway2: {
        id: localNetworkGateway.id
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
    // // These settings will work for connecting to Azure Virtual WAN.  Default will not.
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

resource localNetworkGateway 'Microsoft.Network/localNetworkGateways@2022-11-01' = {
  name: '${vpn_Destination_Name}_LocalNetworkGateway'
  location: location
  properties: {
    gatewayIpAddress: vpn_Destination_PublicIPAddress
    bgpSettings: {
      asn: vpn_Destination_ASN
      bgpPeeringAddress: vpn_Destination_BGPIPAddress
    }
  }
}





















