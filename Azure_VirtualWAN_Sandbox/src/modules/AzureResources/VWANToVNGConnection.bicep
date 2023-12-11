@description('Azure Datacenter region to which these resources will be deployed.')
param location string

@description('Resource ID of the Virtual WAN to which the Virtual Hub is connected.')
param virtualWAN_ID string

@description('Name of the Virtual Hub')
param virtualHub_Name string

@description('Resource ID of the Default Route Table in the Virtual Hub.')
param virtualHub_RouteTable_Default_ResourceID string

@description('Name of the VPN Gateway in the Virtual Hub.')
param virtualWAN_VPNGateway_Name string

@description('Friendly Name of the destination VPN.')
param destinationVPN_Name string

@description('Public IP Address of the destination VPN.')
param destinationVPN_PublicAddress string 

@description('ASN of the destination VPN for BGP connectivity.')
param destinationVPN_ASN int 

@description('BGP Address of the destination VPN.')
param destinationVPN_BGPAddress string

@description('VPN Shared Key used for authenticating VPN connections.  This Shared Key must be the same key that is used on the Virtual Network Gateway that is being connected to the vWAN\'s S2S VPNs.')
@secure()
param vpn_SharedKey string

resource vwan_VPN 'Microsoft.Network/vpnGateways@2023-02-01' existing = {
  name: virtualWAN_VPNGateway_Name
}

resource vpn_Site 'Microsoft.Network/vpnSites@2022-11-01' = {
  name: '${virtualHub_Name}_to_${destinationVPN_Name}'
  location: location
  properties: {
    deviceProperties: {
      deviceVendor: 'Azure'
      linkSpeedInMbps: 0
    }
    virtualWan: {
      id: virtualWAN_ID
    }
    isSecuritySite: false
    o365Policy: {
      breakOutCategories: {
        optimize: false
        allow: false
        default: false
      }
    }
    vpnSiteLinks: [
      {
        name: destinationVPN_Name
        properties: {
          ipAddress: destinationVPN_PublicAddress
          bgpProperties: {
            asn: destinationVPN_ASN
            bgpPeeringAddress: destinationVPN_BGPAddress
          }
          linkProperties: {
            linkProviderName: 'Azure'
            linkSpeedInMbps: 200
          }
        }
      }
    ]
  }
}


resource vpn_Connection 'Microsoft.Network/vpnGateways/vpnConnections@2022-11-01' = {
  parent: vwan_VPN
  name: 'Connection-to_main_hub'
  properties: {
    routingConfiguration: {
      associatedRouteTable: {
        id: virtualHub_RouteTable_Default_ResourceID
      }
      propagatedRouteTables: {
        labels: [
          'default'
        ]
        ids: [
          {
            id: virtualHub_RouteTable_Default_ResourceID
          }
        ]
      }
    }
    enableInternetSecurity: false
    remoteVpnSite: {
      id: vpn_Site.id
    }
    vpnLinkConnections: [
      {
        name: '${virtualHub_Name}_to_OnPrem'
        properties: {
          vpnSiteLink: {
            id: vpn_Site.properties.vpnSiteLinks[0].id
          }
          connectionBandwidth: 10
          ipsecPolicies: [
            {
              saLifeTimeSeconds: 3600
              saDataSizeKilobytes: 0
              ipsecEncryption: 'AES256'
              ipsecIntegrity: 'SHA256'
              ikeEncryption: 'AES256'
              ikeIntegrity: 'SHA256'
              dhGroup: 'DHGroup14'
              pfsGroup: 'None'
            }
          ]
          vpnConnectionProtocolType: 'IKEv2'
          sharedKey: vpn_SharedKey
          enableBgp: true
          enableRateLimiting: false
          useLocalAzureIpAddress: false
          usePolicyBasedTrafficSelectors: false
          routingWeight: 0
          vpnLinkConnectionMode: 'Default'
          vpnGatewayCustomBgpAddresses: []
        }
      }
    ]
  }
}


















