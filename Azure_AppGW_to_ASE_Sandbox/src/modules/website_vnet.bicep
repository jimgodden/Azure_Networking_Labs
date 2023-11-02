@description('Region that the resources are deployed to')
param location string

@description('Name of the Virtual Network for both the Application Gateway and App Service Environment')
param Vnet_Name string

@description('Address Prefix for the Virtual Network')
param Vnet_AddressPrefix string

param Subnet_AppGW_AddressPrefix string

param Subnet_ASE_AddressPrefix string

@description('Name of the Network Security Group on the Application Gateway subnet')
param AppGW_NSG_Name string

@description('Name of the Network Security Group on the App Service Environment subnet')
param ASE_NSG_Name string

resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: Vnet_Name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        Vnet_AddressPrefix
      ]
    }
    dhcpOptions: {
      dnsServers: []
    }
    subnets: [
      {
        name: 'ApplicationGateway_Subnet'
        properties: {
          addressPrefix: Subnet_AppGW_AddressPrefix
          networkSecurityGroup: {
            id: AppGW_NSG.id
          }
          serviceEndpoints: []
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: 'ASE_Subnet'
        properties: {
          addressPrefix: Subnet_ASE_AddressPrefix
          networkSecurityGroup: {
            id: ASE_NSG.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                '*'
              ]
            }
          ]
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
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }
}

resource AppGW_NSG 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: AppGW_NSG_Name
  location: location
  properties: {
    securityRules: []
  }
}

resource AppGW_NSG_AppGWSpecificRule 'Microsoft.Network/networkSecurityGroups/securityRules@2022-11-01' = {
  parent: AppGW_NSG
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

resource ASE_NSG 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: ASE_NSG_Name
  location: location
  properties: {
    securityRules: [
      // {
      //   name: 'AllowCorpnet'
      //   type: 'Microsoft.Network/networkSecurityGroups/securityRules'
      //   properties: {
      //     description: 'CSS Governance Security Rule.  Allow Corpnet inbound.  https://aka.ms/casg'
      //     protocol: '*'
      //     sourcePortRange: '*'
      //     destinationPortRange: '*'
      //     sourceAddressPrefix: 'CorpNetPublic'
      //     destinationAddressPrefix: '*'
      //     access: 'Allow'
      //     priority: 2700
      //     direction: 'Inbound'
      //     sourcePortRanges: []
      //     destinationPortRanges: []
      //     sourceAddressPrefixes: []
      //     destinationAddressPrefixes: []
      //   }
      // }
      // {
      //   name: 'AllowSAW'
      //   type: 'Microsoft.Network/networkSecurityGroups/securityRules'
      //   properties: {
      //     description: 'CSS Governance Security Rule.  Allow SAW inbound.  https://aka.ms/casg'
      //     protocol: '*'
      //     sourcePortRange: '*'
      //     destinationPortRange: '*'
      //     sourceAddressPrefix: 'CorpNetSaw'
      //     destinationAddressPrefix: '*'
      //     access: 'Allow'
      //     priority: 2701
      //     direction: 'Inbound'
      //     sourcePortRanges: []
      //     destinationPortRanges: []
      //     sourceAddressPrefixes: []
      //     destinationAddressPrefixes: []
      //   }
      // }
    ]
  }
}

output vnetName string = vnet.name
output appgwSubnetName string = vnet.properties.subnets[0].name
output aseSubnetName string = vnet.properties.subnets[1].name
