@description('Azure Datacenter location for all resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param virtualMachine_Size string = 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

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
param storageAccount_Name string = 'storagedns${uniqueString(resourceGroup().id)}'

@description('''DNS Zone to be hosted On Prem and with a forwarding rule on the DNS Private Resolver.
Must end with a period (.)
Example:
contoso.com.''')
param onpremResolvableDomainName string = 'contoso.com.'

param tagValues object = {
  Training: 'PrivateResolver_Centralized'
}

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

module Hub_VirtualNetwork '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'Hub_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: location
    virtualNetwork_Name: 'Hub_VNet'
    tagValues: tagValues
  }
}

module Spoke_VirtualNetwork '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'Spoke_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    location: location
    virtualNetwork_Name: 'Spoke_VNet'
    tagValues: tagValues
  }
}

module Hub_To_Spoke_Peering '../../modules/Microsoft.Network/VirtualNetworkPeeringSpoke2Spoke.bicep' = {
  name: 'HubToSpokePeering'
  params: {
    virtualNetwork1_Name: Hub_VirtualNetwork.outputs.virtualNetwork_Name
    virtualNetwork2_Name: Spoke_VirtualNetwork.outputs.virtualNetwork_Name
  }
}

module Hub_to_OnPrem_Peering '../../modules/Microsoft.Network/VirtualNetworkPeeringSpoke2Spoke.bicep' = {
  name: 'HubToOnPremPeering'
  params: {
    virtualNetwork1_Name: Hub_VirtualNetwork.outputs.virtualNetwork_Name
    virtualNetwork2_Name: OnPrem_VirtualNetwork.outputs.virtualNetwork_Name
  }
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
}

module StorageAccount '../../modules/Microsoft.Storage/StorageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    location: location
    storageAccount_Name: storageAccount_Name
    tagValues: tagValues
  }
}

module Hub_StorageAccount_Blob_PrivateEndpoint '../../modules/Microsoft.Network/PrivateEndpoint.bicep' = {
  name: 'Hub_StorageAccount_Blob_PrivateEndpoint'
  params: {
    groupID: 'blob'
    location: location
    privateDNSZone_Name: 'privatelink.blob.${environment().suffixes.storage}'
    privateEndpoint_Name: 'Hub_${storageAccount_Name}_blob_pe'
    privateEndpoint_SubnetID: Hub_VirtualNetwork.outputs.privateEndpoint_SubnetID
    privateLinkServiceId: StorageAccount.outputs.storageAccount_ID
    virtualNetwork_IDs: [Hub_VirtualNetwork.outputs.virtualNetwork_ID]
    tagValues: tagValues
  }
}

module Hub_Bastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'Hub_Bastion'
  params: {
    bastion_SubnetID: Hub_VirtualNetwork.outputs.bastion_SubnetID
    location: location
    bastion_name: 'Hub_bastion'
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

// Updates the VNET to use the OnPrem-WinDNS VM's IP for DNS resolution after the VM has been created
module OnPrem_VirtualNetwork_DnsUpdate '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'OnPrem_VNet_Dns_Update'
  params: {
    virtualNetwork_AddressPrefix: '10.100.0.0/16'
    dnsServers: [
      OnPrem_WinDnsVm.outputs.networkInterface_PrivateIPAddress
    ]
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
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_DNS.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_DNS.ps1 -Username ${virtualMachine_AdminUsername} -SampleDNSZoneName ${onpremResolvableDomainName} -SampleARecord ${cidrHost( OnPrem_VirtualNetwork.outputs.general_Subnet_AddressPrefix, 4 )}'
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
  dependsOn: [
    OnPrem_VirtualNetwork_DnsUpdate
  ]
}
