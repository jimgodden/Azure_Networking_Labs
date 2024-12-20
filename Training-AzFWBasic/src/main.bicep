@description('Azure Datacenter location for the Hub and Spoke A resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param virtualMachine_Size string = 'Standard_D2as_v4' // 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = true

// @description('Set this to true if you want to use an Azure Firewall in the Hub Virtual Network.')
// param usingAzureFirewall bool = true

// @description('SKU for the Azure Firewall')
// param azureFirewall_SKU string = 'Premium'

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

@description('''
Storage account name restrictions:
- Storage account names must be between 3 and 24 characters in length and may contain numbers and lowercase letters only.
- Your storage account name must be unique within Azure. No two storage accounts can have the same name.
''')
@minLength(3)
@maxLength(24)
param storageAccount_Name string

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'


module virtualNetwork_Hub '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'virtualNetwork_Hub'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: location
    virtualNetwork_Name: 'hub_VNet'
  }
}

module virtualNetwork_SpokeA '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'virtualNetwork_SpokeA'
  params: {
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    routeTable_disableBgpRoutePropagation: true
    location: location
    virtualNetwork_Name: 'spokeA_VNet'
  }
}

module virtualNetwork_SpokeB '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'virtualNetwork_SpokeB'
  params: {
    virtualNetwork_AddressPrefix: '10.2.0.0/16'
    routeTable_disableBgpRoutePropagation: true
    location: location
    virtualNetwork_Name: 'spokeB_VNet'
  }
}

module hub_To_SpokeA_Peering '../../modules/Microsoft.Network/VirtualNetworkPeeringHub2Spoke.bicep' = {
  name: 'hubToSpokeAPeering'
  params: {
    virtualNetwork_Hub_Name: virtualNetwork_Hub.outputs.virtualNetwork_Name
    virtualNetwork_Spoke_Name: virtualNetwork_SpokeA.outputs.virtualNetwork_Name
  }
  dependsOn: [
    Hub_to_OnPrem_conn
    OnPrem_to_Hub_conn
  ]
}

module hub_To_SpokeB_Peering '../../modules/Microsoft.Network/VirtualNetworkPeeringHub2Spoke.bicep' = {
  name: 'hubToSpokeBPeering'
  params: {
    virtualNetwork_Hub_Name: virtualNetwork_Hub.outputs.virtualNetwork_Name
    virtualNetwork_Spoke_Name: virtualNetwork_SpokeB.outputs.virtualNetwork_Name
  }
  dependsOn: [
    Hub_to_OnPrem_conn
    OnPrem_to_Hub_conn
  ]
}

module hub_DnsVMs '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = [ for i in range(1, 1) : {
  name: 'hub-DnsVM${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'hub-DnsVM${i}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_DNS.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_DNS.ps1 -Username ${virtualMachine_AdminUsername}'
  }
} ]

module spokeA_WinVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'spokeA-WinVM'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork_SpokeA.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'spokeA-ClientVM'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}

module spokeB_WinVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'spokeB-WinVM'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork_SpokeB.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'spokeB-IISVM'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_WebServer.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_WebServer.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}

module storageAccount '../../modules/Microsoft.Storage/StorageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    location: location
    storageAccount_Name: storageAccount_Name
  }
}

// module hub_StorageAccount_Blob_PrivateEndpoint '../../modules/Microsoft.Network/PrivateEndpoint.bicep' = {
//   name: 'hub_StorageAccount_Blob_PrivateEndpoint'
//   params: {
//     groupID: 'blob'
//     location: location
//     privateDNSZone_Name: 'privatelink.blob.${environment().suffixes.storage}'
//     privateEndpoint_Name: 'hub_${storageAccount_Name}_blob_pe'
//     privateEndpoint_SubnetID: virtualNetwork_Hub.outputs.privateEndpoint_SubnetID
//     privateLinkServiceId: storageAccount.outputs.storageAccount_ID
//     virtualNetwork_IDs: [virtualNetwork_Hub.outputs.virtualNetwork_ID]
//   }
// }

resource azureFirewall_PIP 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: 'AzFW_PIP'
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
  // tags: tagValues
}

resource azureFirewall_Management_PIP 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: 'AzFW_Management_PIP'
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
  // tags: tagValues
}

// module azureFirewall '../../modules/Microsoft.Network/AzureFirewall.bicep' = if (usingAzureFirewall) {
//   name: 'hubAzureFirewall'
//   params: {
//     azureFirewall_ManagementSubnet_ID: virtualNetwork_Hub.outputs.azureFirewallManagement_SubnetID
//     azureFirewall_Name: 'hub_AzFW'
//     azureFirewall_SKU: azureFirewall_SKU
//     azureFirewall_Subnet_ID: virtualNetwork_Hub.outputs.azureFirewall_SubnetID
//     azureFirewallPolicy_Name: 'hub_AzFWPolicy'
//     location: location
//   }
//   dependsOn: [
//     Hub_to_OnPrem_conn
//     OnPrem_to_Hub_conn
//   ]
// }

module udrToAzFW_Hub '../../modules/Microsoft.Network/RouteTable.bicep' = {
  name: 'udrToAzFW_Hub'
  params: {
    addressPrefixs: [
      '10.0.0.0/8'
    ]
    nextHopType: 'VirtualAppliance'
    routeTable_Name: virtualNetwork_Hub.outputs.routeTable_Name
    routeTableRoute_Name: 'toAzFW'
    nextHopIpAddress: '10.0.6.4' // hardcode IP Address
  }
}

module udrToAzFW_SpokeA '../../modules/Microsoft.Network/RouteTable.bicep' = {
  name: 'udrToAzFW_SpokeA'
  params: {
    addressPrefixs: [
      '10.0.0.0/8'
    ]
    nextHopType: 'VirtualAppliance'
    routeTable_Name: virtualNetwork_SpokeA.outputs.routeTable_Name
    routeTableRoute_Name: 'toAzFW'
    nextHopIpAddress: '10.0.6.4'
  }
}

module udrToAzFW_SpokeB '../../modules/Microsoft.Network/RouteTable.bicep' = {
  name: 'udrToAzFW_SpokeB'
  params: {
    addressPrefixs: [
      '10.0.0.0/8'
    ]
    nextHopType: 'VirtualAppliance'
    routeTable_Name: virtualNetwork_SpokeB.outputs.routeTable_Name
    routeTableRoute_Name: 'toAzFW'
    nextHopIpAddress: '10.0.6.4'
  }
}

resource Bastion_VNet 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: 'Bastion_VNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.200.0.0/24'
      ]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.200.0.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    enableDdosProtection: false
  }
}

module bastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_name: 'Bastion'
    bastion_SubnetID: Bastion_VNet.properties.subnets[0].id
    location: location
  }
}

module bastionPeeringToAllVNets '../../modules/Microsoft.Network/BastionVirtualNetworkHubPeerings.bicep' = {
  name: 'bastionPeeringToAllVNets'
  params: {
    bastion_VirtualNetwork_Id: Bastion_VNet.id
    other_VirtualNetwork_Ids: [ 
      virtualNetwork_Hub.outputs.virtualNetwork_ID
      virtualNetwork_SpokeA.outputs.virtualNetwork_ID
      virtualNetwork_SpokeB.outputs.virtualNetwork_ID
      virtualNetwork_OnPremHub.outputs.virtualNetwork_ID
    ]
  }
  dependsOn: [
    hub_To_SpokeA_Peering
    hub_To_SpokeB_Peering
  ]
}

module virtualNetwork_OnPremHub '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'onprem_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.100.0.0/16'
    location: location
    virtualNetwork_Name: 'onprem_VNet'
  }
}

module OnPremVM_Client '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'OnPremWinClient'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork_OnPremHub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'OnPrem-Client'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}

module OnPremVM_WinDNS '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = [for i in range(0, 1) : {
  name: 'OnPremWinDNS${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork_OnPremHub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'OnPrem-WinDNS${i}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_DNS.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_DNS.ps1 -Username ${virtualMachine_AdminUsername}'
  }
} ]

module virtualNetworkGateway_OnPrem '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'OnPremVirtualNetworkGateway'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65000
    virtualNetworkGateway_Name: 'OnPrem_VNG'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork_OnPremHub.outputs.gateway_SubnetID
  }
}

module virtualNetworkGateway_Hub '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'HubVirtualNetworkGateway'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65001
    virtualNetworkGateway_Name: 'Hub_VNG'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork_Hub.outputs.gateway_SubnetID
  }
}

module OnPrem_to_Hub_conn '../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'OnPrem_to_Hub_conn'
  params: {
    location: location
    virtualNetworkGateway_ID: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_ASN: virtualNetworkGateway_Hub.outputs.virtualNetworkGateway_ASN
    vpn_Destination_BGPIPAddress: virtualNetworkGateway_Hub.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_Name: virtualNetworkGateway_Hub.outputs.virtualNetworkGateway_Name
    vpn_Destination_PublicIPAddress: virtualNetworkGateway_Hub.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
  }
}

module Hub_to_OnPrem_conn '../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'Hub_to_OnPrem_conn'
  params: {
    location: location
    virtualNetworkGateway_ID: virtualNetworkGateway_Hub.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_ASN: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_ASN
    vpn_Destination_BGPIPAddress: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_Name: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_Name
    vpn_Destination_PublicIPAddress: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
  }
}
