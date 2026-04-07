@description('Azure Datacenter location for the resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param virtualMachine_Size string = 'Standard_D2as_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = true

// ---- Virtual Network ----
// Subnet layout (all /24 within 10.0.0.0/16):
//   General          (10.0.0.0/24) - Source VM
//   PrivateEndpoints (10.0.1.0/24) - Destination VM
//   AzureFirewallSubnet (10.0.6.0/24)
//   AzureFirewallManagementSubnet (10.0.7.0/24)
//   AzureBastionSubnet (10.0.8.0/24)
module virtualNetwork '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    virtualNetwork_Name: 'vnet'
  }
}

// ---- UDRs to route inter-subnet traffic through Azure Firewall ----
module routeTable_SourceToDestination '../../../modules/Microsoft.Network/RouteTable.bicep' = {
  name: 'routeTable_toFirewall'
  params: {
    routeTable_Name: virtualNetwork.outputs.routeTable_Name
    routeTableRoute_Name: 'toFirewall'
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
    addressPrefixs: [
      '10.0.0.0/24'   // General subnet (source)
      '10.0.1.0/24'   // PrivateEndpoints subnet (destination)
    ]
  }
}

// ---- Azure Firewall (Basic SKU) ----
resource azureFirewall_PIP 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'AzFW_PIP'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource azureFirewall_Management_PIP 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'AzFW_Management_PIP'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource azureFirewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: 'AzFW_Policy'
  location: location
  properties: {
    sku: {
      tier: 'Basic'
    }
  }
}

resource azureFirewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: 'AzFW'
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Basic'
    }
    managementIpConfiguration: {
      name: 'managementIpConfig'
      properties: {
        publicIPAddress: {
          id: azureFirewall_Management_PIP.id
        }
        subnet: {
          id: virtualNetwork.outputs.azureFirewallManagement_SubnetID
        }
      }
    }
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          publicIPAddress: {
            id: azureFirewall_PIP.id
          }
          subnet: {
            id: virtualNetwork.outputs.azureFirewall_SubnetID
          }
        }
      }
    ]
    firewallPolicy: {
      id: azureFirewallPolicy.id
    }
  }
}

// ---- Azure Firewall Network Rule: Allow TCP 3389 (RDP) ----
resource azureFirewallPolicy_NetworkRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: azureFirewallPolicy
  name: 'DefaultNetworkRuleCollectionGroup'
  dependsOn: [
    azureFirewall
  ]
  properties: {
    priority: 200
    ruleCollections: [
      {
        name: 'AllowRDP'
        priority: 100
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Allow_TCP_3389'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.0.0.0/24'
            ]
            destinationAddresses: [
              '10.0.1.0/24'
            ]
            destinationPorts: [
              '3389'
            ]
          }
        ]
      }
    ]
  }
}

// ---- Azure Firewall Application Rule: Allow HTTPS (port 443) ----
resource azureFirewallPolicy_ApplicationRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: azureFirewallPolicy
  name: 'DefaultApplicationRuleCollectionGroup'
  dependsOn: [
    azureFirewallPolicy_NetworkRules
  ]
  properties: {
    priority: 300
    ruleCollections: [
      {
        name: 'AllowHTTPS'
        priority: 100
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'Allow_HTTPS_443'
            sourceAddresses: [
              '10.0.0.0/24'
            ]
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              '*'
            ]
          }
        ]
      }
    ]
  }
}

// ---- Source Windows VM (IIS WebServer) in General Subnet ----
module sourceVM '../../../modules/Microsoft.Compute/VirtualMachine/Windows/Server2025_WebServer.bicep' = {
  name: 'sourceVM'
  params: {
    location: location
    virtualMachine_Name: 'sourceVM'
    vmSize: virtualMachine_Size
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    acceleratedNetworking: acceleratedNetworking
    subnet_ID: virtualNetwork.outputs.general_SubnetID
  }
}

// ---- Destination Windows VM (IIS WebServer) in PrivateEndpoints Subnet ----
module destinationVM '../../../modules/Microsoft.Compute/VirtualMachine/Windows/Server2025_WebServer.bicep' = {
  name: 'destinationVM'
  params: {
    location: location
    virtualMachine_Name: 'destinationVM'
    vmSize: virtualMachine_Size
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    acceleratedNetworking: acceleratedNetworking
    subnet_ID: virtualNetwork.outputs.privateEndpoint_SubnetID
  }
}

// ---- Azure Bastion (Basic SKU) ----
module bastion '../../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastiondeployment'
  params: {
    bastion_name: 'bastion'
    bastion_SubnetID: virtualNetwork.outputs.bastion_SubnetID
    location: location
    bastion_SKU: 'Basic'
  }
}

// ---- Log Analytics Workspace (for Connection Monitor) ----
module workspace '../../../modules/Microsoft.OperationalInsights/Workspaces.bicep' = {
  name: 'workspace'
  params: {
    location: location
    Workspaces_name: 'azfw-connmon-law'
  }
}

// ---- Storage Account (for Flow Logs) ----
module storageAccount '../../../modules/Microsoft.Storage/StorageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    location: location
    storageAccount_Name: 'tempstor${uniqueString(resourceGroup().id)}'
  }
}

// ---- Network Watcher Connection Monitor & Flow Logs ----
module networkWatcher './networkWatcher.bicep' = {
  name: 'networkWatcher'
  scope: resourceGroup('NetworkWatcherRG')
  params: {
    location: location
    sourceVM_ResourceId: sourceVM.outputs.virtualMachine_Id
    destinationVM_ResourceId: destinationVM.outputs.virtualMachine_Id
    workspaceResourceId: workspace.outputs.LogAnalyticsWorkspace_ID
    storageAccountId: storageAccount.outputs.storageAccount_ID
    virtualNetwork_ResourceId: virtualNetwork.outputs.virtualNetwork_ID
  }
}

// ---- Outputs ----
output sourceVM_Name string = sourceVM.outputs.virtualMachine_Name
output sourceVM_PrivateIP string = sourceVM.outputs.networkInterface_PrivateIPAddress
output destinationVM_Name string = destinationVM.outputs.virtualMachine_Name
output destinationVM_PrivateIP string = destinationVM.outputs.networkInterface_PrivateIPAddress
output azureFirewall_PrivateIP string = azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
