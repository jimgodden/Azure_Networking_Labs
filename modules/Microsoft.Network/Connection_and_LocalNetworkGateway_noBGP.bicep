@description('Azure Datacenter that the source VNG is deployed')
param location string

@description('Friendly name for the destination VPN device')
param vpn_Destination_Name string

@description('Public IP Address of the Destination VPN.  Use this or FQDN.  Not both.')
param vpn_Destination_PublicIPAddress string

@description('FQDN of the Destination VPN.  Use this or Public IP Address.  Not both.')
param vpn_Destination_FQDN string = ''

@description('Address Prefix')
param vpn_Destination_LocalAddressPrefix string

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

@description('Option to add an additional identifier in case two LNGs of the same name might get created.')
param lngOptionalTag string = ''

@description('Source Virtual Network Gateway ID')
param virtualNetworkGateway_ID string

param tagValues object = {}

var virtualNetworkGateway_ID_Split = split(virtualNetworkGateway_ID, '/')
var virtualNetworkGateway_Name = virtualNetworkGateway_ID_Split[8] 

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
    enableBgp: false
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
  tags: tagValues
}

resource localNetworkGateway 'Microsoft.Network/localNetworkGateways@2022-11-01' = {
  name: 'Lng_for_${virtualNetworkGateway_Name}_to_${vpn_Destination_Name}${lngOptionalTag}'
  location: location
  properties: {
    gatewayIpAddress: vpn_Destination_PublicIPAddress
    fqdn: vpn_Destination_FQDN
    localNetworkAddressSpace: {
      addressPrefixes: [
        vpn_Destination_LocalAddressPrefix
      ]
    }
  }
  tags: tagValues
}
