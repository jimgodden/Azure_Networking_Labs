@description('Azure Datacenter location that the main resouces will be deployed to.')
param location string

@description('Name of the Azure Firewall within the vHub A')
param azureFirewall_Name string

@description('Sku name of the Azure Firewall.  Allowed values are Basic, Standard, and Premium')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param azureFirewall_SKU string

@description('Name of the Azure Firewall Policy')
param azureFirewallPolicy_Name string

@description('Resource ID of the Azure Firewall Subnet.  Note: The subnet name must be "AzureFirewallSubnet')
param azureFirewall_Subnet_ID string

@description('Resource ID of the Azure Firewall Management Subnet.  Note: The subnet name must be "AzureFirewallManagementSubnet')
param azureFirewall_ManagementSubnet_ID string

param tagValues object = {}

resource azureFirewall_PIP 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: '${azureFirewall_Name}_PIP'
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
  tags: tagValues
}

resource azureFirewall_Management_PIP 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: '${azureFirewall_Name}_Management_PIP'
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
  tags: tagValues
}

resource azureFirewallPolicy 'Microsoft.Network/firewallPolicies@2022-07-01' = {
  name: azureFirewallPolicy_Name
  location: location
  properties: {
    sku: {
      tier: azureFirewall_SKU
    }
  }
  tags: tagValues
}

resource azureFirewall 'Microsoft.Network/azureFirewalls@2022-11-01' = {
  name: azureFirewall_Name
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: azureFirewall_SKU
    }
    additionalProperties: {}
    managementIpConfiguration: {
      name: 'managementipconfig'
      properties: {
        publicIPAddress: {
          id: azureFirewall_Management_PIP.id
        }
        subnet: {
          id: azureFirewall_ManagementSubnet_ID
        }
      }
     }
    ipConfigurations: [
       {
         name: 'ipconfiguration'
         properties: {
          publicIPAddress: {
            id: azureFirewall_PIP.id
          }
           subnet: {
            id: azureFirewall_Subnet_ID
           }
         }
       }
    ]
    firewallPolicy: {
      id: azureFirewallPolicy.id
    }
  }
  tags: tagValues
}


resource azureFirewallPolicy_Rule 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-05-01' = {
  parent: azureFirewallPolicy
  name: 'DefaultNetworkRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: [
       {
        name: 'allowall'
        priority: 100
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
           {
            ruleType: 'NetworkRule'
            name: 'any'
            ipProtocols: [
              'any'
            ]
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '*'
            ]
           }
        ]
       }
    ]
  }
}


output azureFirewall_PrivateIPAddress string = azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
