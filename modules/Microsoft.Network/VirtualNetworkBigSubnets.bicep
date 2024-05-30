@description('Azure Datacenter that the resource is deployed to')
param location string

@description('Name of the Virtual Network')
param virtualNetwork_Name string

@description('''An Array of Custom DNS Server IP Addresses.  Azure Wireserver will be used if left as an empty array [].
Example:
[10.0.0.4, 10.0.0.5]
''')
param dnsServers array = []

@description('Name of the General Network Security Group')
param networkSecurityGroup_Default_Name string = '${virtualNetwork_Name}_NSG_General'

@description('Name of the General Route Table')
param routeTable_Name string = '${virtualNetwork_Name}_RT_General'

param virtualNetwork_AddressPrefix string

param tagValues object = {}

var subnet_AddressRangeCIDRs = [for i in range(0, 255): cidrSubnet(virtualNetwork_AddressPrefix, 20, i) ]

var subnet_Names = [
  'General'
  'PrivateEndpoints'
  'AzureBastionSubnet'
]

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: virtualNetwork_Name
  location: location
  properties: {
    dhcpOptions: {
      dnsServers: dnsServers
    }
    addressSpace: {
      addressPrefixes: [
        virtualNetwork_AddressPrefix
      ]
    }
    subnets: [
      {
        name: subnet_Names[0]
        properties: {
          addressPrefix: subnet_AddressRangeCIDRs[0]
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
        name: subnet_Names[1]
        properties: {
          addressPrefix: subnet_AddressRangeCIDRs[1]
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
        name: subnet_Names[2]
        properties: {
          addressPrefix: subnet_AddressRangeCIDRs[8]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    enableDdosProtection: false
  }
  tags: tagValues
}

resource routeTable 'Microsoft.Network/routeTables@2023-02-01' = {
  name: routeTable_Name
  location: location
  properties: {
    disableBgpRoutePropagation: false
  }
  tags: tagValues
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: networkSecurityGroup_Default_Name
  location: location
  properties: {
  }
  tags: tagValues
}

output general_SubnetID string = virtualNetwork.properties.subnets[0].id
output privateEndpoint_SubnetID string = virtualNetwork.properties.subnets[1].id
output bastion_SubnetID string = virtualNetwork.properties.subnets[2].id

output general_Subnet_AddressPrefix string = virtualNetwork.properties.subnets[0].properties.addressPrefix
output privateEndpoint_Subnet_AddressPrefix string = virtualNetwork.properties.subnets[1].properties.addressPrefix
output bastion_Subnet_AddressPrefix string = virtualNetwork.properties.subnets[2].properties.addressPrefix

output virtualNetwork_Name string = virtualNetwork.name
output virtualNetwork_ID string = virtualNetwork.id
output virtualNetwork_AddressPrefix string = virtualNetwork.properties.addressSpace.addressPrefixes[0]

output routeTable_Name string = routeTable.name

output networkSecurityGroup_Name string = networkSecurityGroup.name
