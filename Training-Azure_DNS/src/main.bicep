@description('Azure Datacenter location for all resources')
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
param acceleratedNetworking bool = false

@description('''
Storage account name restrictions:
- Storage account names must be between 3 and 24 characters in length and may contain numbers and lowercase letters only.
- Your storage account name must be unique within Azure. No two storage accounts can have the same name.
''')
@minLength(3)
@maxLength(24)
param storageAccount_Name string

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

param tagValues object = {
  Training: 'AzureDNS'
}

@description('SKU of the Virtual Network Gateway')
var virtualNetworkGateway_SKU = 'VpnGw1'

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

module Hub_VirtualNetwork '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'Hub_VirtualNetwork'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: location
    virtualNetwork_Name: 'Hub_VNet'
    tagValues: tagValues
  }
}

module Spoke_VirtualNetwork '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'Spoke_VirtualNetwork'
  params: {
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    location: location
    virtualNetwork_Name: 'Spoke_VNet'
    tagValues: tagValues
  }
}

module Hub_To_Spoke_Peering '../../modules/Microsoft.Network/VirtualNetworkPeeringHub2Spoke.bicep' = {
  name: 'Hub_To_Spoke_Peering'
  params: {
    virtualNetwork_Hub_Name: Hub_VirtualNetwork.outputs.virtualNetwork_Name
    virtualNetwork_Spoke_Name: Spoke_VirtualNetwork.outputs.virtualNetwork_Name
  }
  dependsOn: [
    Hub_VirtualNetworkGateway
  ]
}


module Hub_WinClientVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'Hub-WinClientVM'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: Hub_VirtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'Hub-WinClient'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
    privateIPAddress: cidrHost( Hub_VirtualNetwork.outputs.general_Subnet_AddressPrefix, 3 )
    privateIPAllocationMethod: 'Static'
    tagValues: tagValues
  }
}

module Spoke_WinClientVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'spoke-WinClientVM'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: Spoke_VirtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'Spoke-WinClient'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
    privateIPAddress: cidrHost( Spoke_VirtualNetwork.outputs.general_Subnet_AddressPrefix, 3 )
    privateIPAllocationMethod: 'Static'
    tagValues: tagValues
  }
  dependsOn: [
    Hub_To_Spoke_Peering
  ]
}

module StorageAccount '../../modules/Microsoft.Storage/StorageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    location: location
    storageAccount_Name: storageAccount_Name
    tagValues: tagValues
  }
}

resource StorageAccount_PrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'StorageAccount_PrivateEndpoint'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'PrivateEndpoint_to_StorageAccount'
        properties: {
          privateLinkServiceId: StorageAccount.outputs.storageAccount_ID
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    subnet: {
      id: Hub_VirtualNetwork.outputs.privateEndpoint_SubnetID
    }
  }
  tags: tagValues
}

module Hub_Bastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'Hub_Bastion'
  params: {
    bastion_SubnetID: Hub_VirtualNetwork.outputs.bastion_SubnetID
    location: location
    bastion_name: 'Hub_Bastion'
    tagValues: tagValues
  }
  
}

module OnPrem_Bastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'OnPrem_Bastion'
  params: {
    bastion_SubnetID: OnPrem_VirtualNetwork.outputs.bastion_SubnetID
    location: location
    bastion_name: 'OnPrem_Bastion'
    tagValues: tagValues
  }
}

module OnPrem_VirtualNetwork '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'OnPrem_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.100.0.0/16'
    location: location
    virtualNetwork_Name: 'OnPrem_VNet'
    tagValues: tagValues
  }
}



module OnPrem_WinDnsVm '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'OnPremWinDNS'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: OnPrem_VirtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'OnPrem-WinDns'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
    privateIPAddress: cidrHost( OnPrem_VirtualNetwork.outputs.general_Subnet_AddressPrefix, 3 )
    privateIPAllocationMethod: 'Static'
    tagValues: tagValues
  }
}

module OnPrem_WinClientVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'OnPrem-WinClientVM'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: OnPrem_VirtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'OnPrem-WinClien'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
    privateIPAddress: cidrHost( OnPrem_VirtualNetwork.outputs.general_Subnet_AddressPrefix, 4 )
    privateIPAllocationMethod: 'Static'
    tagValues: tagValues
  }
}


module OnPrem_VirtualNetworkGateway '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'OnPrem_VNG'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65530
    virtualNetworkGateway_Name: 'OnPrem_VNG'
    virtualNetworkGateway_Subnet_ResourceID: OnPrem_VirtualNetwork.outputs.gateway_SubnetID
    virtualNetworkGateway_SKU: virtualNetworkGateway_SKU
    tagValues: tagValues
  }
}

module Hub_VirtualNetworkGateway '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'Hub_VNG'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65531
    virtualNetworkGateway_Name: 'Hub_VNG'
    virtualNetworkGateway_Subnet_ResourceID: Hub_VirtualNetwork.outputs.gateway_SubnetID
    virtualNetworkGateway_SKU: virtualNetworkGateway_SKU
    tagValues: tagValues
  }
}

// Connections to the other Virtual Network Gateway
module OnPrem_VNG_Conn '../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'OnPrem_VNG_conn'
  params: {
    vpn_Destination_BGPIPAddress: Hub_VirtualNetworkGateway.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_ASN: Hub_VirtualNetworkGateway.outputs.virtualNetworkGateway_ASN
    virtualNetworkGateway_ID: OnPrem_VirtualNetworkGateway.outputs.virtualNetworkGateway_ResourceID
    location: location
    vpn_Destination_Name: 'Hub'
    vpn_SharedKey: vpn_SharedKey
    vpn_Destination_PublicIPAddress: Hub_VirtualNetworkGateway.outputs.virtualNetworkGateway_PublicIPAddress
    tagValues: tagValues
  }
}

module Hub_VNG_Conn '../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'Hub_VNG_conn'
  params: {
    vpn_Destination_BGPIPAddress: OnPrem_VirtualNetworkGateway.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_ASN: OnPrem_VirtualNetworkGateway.outputs.virtualNetworkGateway_ASN
    virtualNetworkGateway_ID: Hub_VirtualNetworkGateway.outputs.virtualNetworkGateway_ResourceID
    location: location
    vpn_Destination_Name: 'OnPrem'
    vpn_SharedKey: vpn_SharedKey
    vpn_Destination_PublicIPAddress: OnPrem_VirtualNetworkGateway.outputs.virtualNetworkGateway_PublicIPAddress
    tagValues: tagValues
  }
}
