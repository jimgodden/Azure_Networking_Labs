@description('Azure Datacenter that the resources are deployed to')
param location string

@description('Friendly Name of the Destination Virtual Hub VPN Gateway')
param destinationVPN_Name array

@description('Public IP Address of the destination VPN.')
param destinationVPN_PublicAddress array 

@description('ASN of the destination VPN for BGP connectivity.')
param destinationVPN_ASN array 

@description('BGP Address of the destination VPN.')
param destinationVPN_BGPAddress array



// @description('Friendly Name of the Destination Virtual Hub VPN Gateway')
// param destinationVPN_Instance0_Name string

// @description('Public IP Address of the destination VPN.')
// param destinationVPN_Instance0_PublicAddress string 

// @description('ASN of the destination VPN for BGP connectivity.')
// param destinationVPN_Instance0_ASN int 

// @description('BGP Address of the destination VPN.')
// param destinationVPN_Instance0_BGPAddress string

// @description('Friendly Name of the Destination Virtual Hub VPN Gateway')
// param destinationVPN_Instance1_Name string

// @description('Public IP Address of the destination VPN.')
// param destinationVPN_Instance1_PublicAddress string 

// @description('ASN of the destination VPN for BGP connectivity.')
// param destinationVPN_Instance1_ASN int 

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

@description('Existing Virtual Network Gateway ID')
param source_VirtualNetworkGateway_ResourceID string


resource connection 'Microsoft.Network/connections@2022-11-01' = [ for i in range(0, length(destinationVPN_Name)) : {
  name: 'OnPrem_to_${destinationVPN_Name[i]}'
  location: location
  properties: {
    virtualNetworkGateway1: {
      id: source_VirtualNetworkGateway_ResourceID
      properties: {
        
      }
    }
    localNetworkGateway2: {
      id: localNetworkGateway[i].id
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
    ipsecPolicies: [
      {
        saLifeTimeSeconds: 3600
        saDataSizeKilobytes: 102400000
        ipsecEncryption: 'AES256'
        ipsecIntegrity: 'SHA256'
        ikeEncryption: 'AES256'
        ikeIntegrity: 'SHA256'
        dhGroup: 'DHGroup14'
        pfsGroup: 'None'
      }
    ]
    dpdTimeoutSeconds: 45
    connectionMode: 'Default'
}
} ]

// resource connection0 'Microsoft.Network/connections@2022-11-01' = {
//     name: 'OnPrem_to_vhub_${vhubIteration}_0'
//     location: location
//     properties: {
//       virtualNetworkGateway1: {
//         id: source_VirtualNetworkGateway_ResourceID
//         properties: {
          
//         }
//       }
//       localNetworkGateway2: {
//         id: lng0.id
//         properties: {
          
//         }
//       }
//       connectionType: 'IPsec'
//       connectionProtocol: 'IKEv2'
//       routingWeight: 0
//       sharedKey: vpn_SharedKey
//       enableBgp: true
//       useLocalAzureIpAddress: false 
//       usePolicyBasedTrafficSelectors: false
//       ipsecPolicies: [
//         {
//           saLifeTimeSeconds: 3600
//           saDataSizeKilobytes: 102400000
//           ipsecEncryption: 'AES256'
//           ipsecIntegrity: 'SHA256'
//           ikeEncryption: 'AES256'
//           ikeIntegrity: 'SHA256'
//           dhGroup: 'DHGroup14'
//           pfsGroup: 'None'
//         }
//       ]
//       dpdTimeoutSeconds: 45
//       connectionMode: 'Default'
//   }
// }

// resource connection1 'Microsoft.Network/connections@2022-11-01' = {
//   name: 'OnPrem_to_vhub_${vhubIteration}_1'
//   location: location
//   properties: {
//     virtualNetworkGateway1: {
//       id: source_VirtualNetworkGateway_ResourceID
//       properties: {
        
//       }
//     }
//     localNetworkGateway2: {
//       id: lng1.id
//       properties: {
        
//       }
//     }
//     connectionType: 'IPsec'
//     connectionProtocol: 'IKEv2'
//     routingWeight: 0
//     sharedKey: vpn_SharedKey
//     enableBgp: true
//     useLocalAzureIpAddress: false 
//     usePolicyBasedTrafficSelectors: false
//     ipsecPolicies: [
//       {
//         saLifeTimeSeconds: 3600
//         saDataSizeKilobytes: 102400000
//         ipsecEncryption: 'AES256'
//         ipsecIntegrity: 'SHA256'
//         ikeEncryption: 'AES256'
//         ikeIntegrity: 'SHA256'
//         dhGroup: 'DHGroup14'
//         pfsGroup: 'None'
//       }
//     ]
//     dpdTimeoutSeconds: 45
//     connectionMode: 'Default'
// }
// }



resource localNetworkGateway 'Microsoft.Network/localNetworkGateways@2022-11-01' = [ for i in range(0, length(destinationVPN_Name)) : {
  name: 'OnPrem_lng_for_${destinationVPN_Name[i]}'
  location: location
  properties: {
    gatewayIpAddress: destinationVPN_PublicAddress[i]
    bgpSettings: {
      asn: destinationVPN_ASN[i]
      bgpPeeringAddress: destinationVPN_BGPAddress[i]
    }
  }
} ]


// resource lng0 'Microsoft.Network/localNetworkGateways@2022-11-01' = {
//   name: 'OnPrem_lng_for_vhub_${vhubIteration}_0'
//   location: location
//   properties: {
//     gatewayIpAddress: destinationVPN_Instance0_PublicAddress
//     bgpSettings: {
//       asn: virtualWAN_ASN
//       bgpPeeringAddress: destinationVPN_Instance0_BGPAddress
//     }
//   }
// }

// resource lng1 'Microsoft.Network/localNetworkGateways@2022-11-01' = {
//   name: 'OnPrem_lng_for_vhub_${vhubIteration}_1'
//   location: location
//   properties: {
//     gatewayIpAddress: destinationVPN_Instance1_PublicAddress
//     bgpSettings: {
//       asn: virtualWAN_ASN
//       bgpPeeringAddress: destinationVPN_Instance1_BGPAddress
//     }
//   }
// }
