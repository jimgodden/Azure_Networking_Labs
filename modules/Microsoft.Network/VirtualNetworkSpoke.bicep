@description('Azure Datacenter that the resource is deployed to')
param location string

@description('Name of the Virtual Network')
param virtualNetwork_Name string

@description('Address Prefix of the Virtual Network')
param virtualNetwork_AddressPrefix string = '${firstTwoOctetsOfVirtualNetworkPrefix}.0.0/16'

@description('Name of the Network Security Group')
param networkSecurityGroup_Default_Name string

@description('Name of the Route Table')
param routeTable_Name string

@description('''First two octects of the Virtual Network address prefix
Example: for a network address of '10.0.0.0/16' you would enter '10.0' here''')
param firstTwoOctetsOfVirtualNetworkPrefix string

// Subnets
@description('Name of the General Subnet for any other resources')
param subnet_General_Name string = 'General'

@description('Address Prefix of the General Subnet')
param subnet_General_AddressPrefix string = '${firstTwoOctetsOfVirtualNetworkPrefix}.0.0/24'

@description('Name of the PrivateEndpoint Subnet')
param subnet_PrivateEndpoints_Name string = 'PrivateEndpoints'

@description('Address Prefix of the PrivateEndpoint Subnet')
param subnet_PrivateEndpoints_AddressPrefix string = '${firstTwoOctetsOfVirtualNetworkPrefix}.1.0/24'

@description('Name of the PrivateEndpoint Subnet')
param subnet_PrivateLinkService_Name string = 'PrivateLinkService'

@description('Address Prefix of the PrivateEndpoint Subnet')
param subnet_PrivateLinkService_AddressPrefix string = '${firstTwoOctetsOfVirtualNetworkPrefix}.2.0/24'



resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: virtualNetwork_Name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetwork_AddressPrefix
      ]
    }
    subnets: [
      {
        name: subnet_General_Name
        properties: {
          addressPrefix: subnet_General_AddressPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          routeTable: {
            id: routeTable.id
          }
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: subnet_PrivateEndpoints_Name
        properties: {
          addressPrefix: subnet_PrivateEndpoints_AddressPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          routeTable: {
            id: routeTable.id
          }
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: subnet_PrivateLinkService_Name
        properties: {
          addressPrefix: subnet_PrivateLinkService_AddressPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          routeTable: {
            id: routeTable.id
          }
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled' // This has to be disabled for Private Link Service to be used in the subnet
        }
      }
    ]
    enableDdosProtection: false
  }
}

resource routeTable 'Microsoft.Network/routeTables@2023-02-01' = {
  name: routeTable_Name
  location: location
  properties: {
    disableBgpRoutePropagation: false
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: networkSecurityGroup_Default_Name
  location: location
  properties: {
  }
}

// resource networkSecurityGroupRule 'Microsoft.Network/networkSecurityGroups/securityRules@2022-09-01' = {
//   parent: networkSecurityGroup
//   name: networkSecurityGroup_Default_RuleName
//   properties: {
//     description: 'test'
//     protocol: '*'
//     sourcePortRange: '*'
//     destinationPortRange: '8080'
//     sourceAddressPrefix: '10.0.0.1/32'
//     destinationAddressPrefix: '*'
//     access: 'Allow'
//     priority: int(networkSecurityGroup_Default_RulePriority)
//     direction: 'Inbound'
//     sourcePortRanges: []
//     destinationPortRanges: []
//     sourceAddressPrefixes: []
//     destinationAddressPrefixes: []
//   }
// }

output general_SubnetID string = virtualNetwork.properties.subnets[0].id
output privateEndpoint_SubnetID string = virtualNetwork.properties.subnets[1].id
output privateLinkService_SubnetID string = virtualNetwork.properties.subnets[2].id

output virtualNetwork_Name string = virtualNetwork.name
output virtualNetwork_ID string = virtualNetwork.id
