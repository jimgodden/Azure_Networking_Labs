@description('Azure Datacenter that the resource is deployed to')
param location string

@description('Name of the Virtual Network')
param virtualNetwork_Name string

@description('Address Prefix of the Virtual Network')
param virtualNetwork_AddressPrefix string = '${firstTwoOctetsOfVirtualNetworkPrefix}.0.0/16'

@description('Name of the General Network Security Group')
param networkSecurityGroup_Default_Name string = '${virtualNetwork_Name}_NSG_General'

@description('Name of the General Route Table')
param routeTable_Name string = '${virtualNetwork_Name}_RT_General'

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

@description('Name of the ApplicationGateway Subnet')
param subnet_ApplicationGatewaySubnet_Name string = 'ApplicationGatewaySubnet'

@description('Address Prefix of the ApplicationGateway Subnet')
// Any changes to this value need to be replicated to the output applicationGatewayPrivateIP
param subnet_ApplicationGatewaySubnet_AddressPrefix string = '${firstTwoOctetsOfVirtualNetworkPrefix}.3.0/24'

@description('Name of the AppService Subnet')
param subnet_AppServiceSubnet_Name string = 'AppServiceSubnet'

@description('Address Prefix of the AppService Subnet')
param subnet_AppServiceSubnet_AddressPrefix string = '${firstTwoOctetsOfVirtualNetworkPrefix}.4.0/24'

@description('Name of the Azure Virtual Network Gateway Subnet')
param subnet_Gateway_Name string = 'GatewaySubnet'

@description('Address Prefix of the Azure Virtual Network Gateway Subnet')
param subnet_Gateway_AddressPrefix string = '${firstTwoOctetsOfVirtualNetworkPrefix}.5.0/24'

@description('Name of the Azure Firewall Subnet')
param subnet_azureFirewall_Name string = 'AzureFirewallSubnet'

@description('Address Prefix of the Azure Firewall Subnet')
param subnet_azureFirewall_AddressPrefix string = '${firstTwoOctetsOfVirtualNetworkPrefix}.6.0/24'

@description('Name of the Azure Firewall Management Subnet')
param subnet_azureFirewall_Management_Name string = 'AzureFirewallManagementSubnet'

@description('Address Prefix of the Azure Firewall Management Subnet')
param subnet_azureFirewall_Management_AddressPrefix string = '${firstTwoOctetsOfVirtualNetworkPrefix}.7.0/24'

@description('Name of the Azure Bastion Subnet')
param subnet_Bastion_Name string = 'AzureBastionSubnet'

@description('Address Prefix of the Azure Bastion Subnet')
param subnet_Bastion_AddressPrefix string = '${firstTwoOctetsOfVirtualNetworkPrefix}.8.0/24'





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
      {
        name: subnet_ApplicationGatewaySubnet_Name
        properties: {
          addressPrefix: subnet_ApplicationGatewaySubnet_AddressPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup_ApplicationGateway.id
          }
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled' 
        }
      }
      {
        name: subnet_AppServiceSubnet_Name
        properties: {
          addressPrefix: subnet_AppServiceSubnet_AddressPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
              type: 'Microsoft.Network/virtualNetworks/subnets/delegations'
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: subnet_Gateway_Name
        properties: {
          addressPrefix: subnet_Gateway_AddressPrefix
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: subnet_azureFirewall_Name
        properties: {
          addressPrefix: subnet_azureFirewall_AddressPrefix
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: subnet_azureFirewall_Management_Name
        properties: {
          addressPrefix: subnet_azureFirewall_Management_AddressPrefix
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: subnet_Bastion_Name
        properties: {
          addressPrefix: subnet_Bastion_AddressPrefix
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
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

resource networkSecurityGroup_ApplicationGateway 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'networkSecurityGroup_ApplicationGateway'
  location: location
  properties: {
    securityRules: []
  }
}

resource networkSecurityGroup_ApplicationGateway_AppGWSpecificRule 'Microsoft.Network/networkSecurityGroups/securityRules@2022-11-01' = {
  parent: networkSecurityGroup_ApplicationGateway
  name: 'AllowGatewayManager'
  properties: {
    description: 'Allow GatewayManager'
    protocol: '*'
    sourcePortRange: '*'
    destinationPortRange: '65200-65535'
    sourceAddressPrefix: 'GatewayManager'
    destinationAddressPrefix: '*'
    access: 'Allow'
    priority: 1000
    direction: 'Inbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
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
output applicationGateway_SubnetID string = virtualNetwork.properties.subnets[3].id 
output appService_SubnetID string = virtualNetwork.properties.subnets[4].id
output gateway_SubnetID string = virtualNetwork.properties.subnets[5].id
output azureFirewall_SubnetID string = virtualNetwork.properties.subnets[6].id
output azureFirewallManagement_SubnetID string = virtualNetwork.properties.subnets[7].id
output bastion_SubnetID string = virtualNetwork.properties.subnets[8].id

// Should be one of the last IPs in the subnet range.  This is for the appgw frontend private ip.
output applicationGateway_PrivateIP string = '${firstTwoOctetsOfVirtualNetworkPrefix}.3.254' 

output virtualNetwork_Name string = virtualNetwork.name
output virtualNetwork_ID string = virtualNetwork.id
