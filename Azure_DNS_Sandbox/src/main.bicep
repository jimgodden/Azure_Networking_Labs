@description('Azure Datacenter location for the Hub and Spoke A resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Password for the Virtual Machine Admin User')
param virtualMachine_Size string = 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

param virtualMachine_ScriptFileLocation string = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

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

@description('Name of the Private DNS Zone that the Virtual Networks will be registered with.')
param privateDNSZone_Name string = 'azure-contoso.com'

@description('Name of the DNS Zone for public DNS resolution.')
param publicDNSZone_Name string = 'DNSSandboxTest${uniqueString(resourceGroup().id)}.com'

@description('''DNS Zone to be hosted On Prem and with a forwarding rule on the DNS Private Resolver.
Must end with a period (.)
Example:
contoso.com.''')
param onpremResolvableDomainName string = 'contoso.com.'

module Hub_VirtualNetwork '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'Hub_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: location
    virtualNetwork_Name: 'Hub_VNet'
  }
}

module Spoke_VirtualNetwork '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'Spoke_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    dnsServers: [ Hub_DnsPrivateResolver.outputs.privateDNSResolver_Inbound_Endpoint_IPAddress ]
    location: location
    virtualNetwork_Name: 'Spoke_VNet'
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

module Hub_WinDnsVm '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'Hub-WinDnsVm'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: Hub_VirtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'Hub-WinDnsVm'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_DNS.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_DNS.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}


module Hub_WinClientVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'Hub-WinClientVM'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: Spoke_VirtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'Hub-WinClient'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
  }
  dependsOn: [
    Hub_WinDnsVm
  ]
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
  }
  dependsOn: [
    Hub_To_Spoke_Peering
    Spoke_WinIisVm
  ]
}

module Spoke_WinIisVm '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'spoke-WinIis'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: Spoke_VirtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'Spoke-WinIis'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_WebServer.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_WebServer.ps1 -Username ${virtualMachine_AdminUsername} -FQDN Spoke-WinIis.${privateDNSZone_Name}'
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
  }
}

module Hub_Bastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'Hub_Bastion'
  params: {
    bastion_SubnetID: Hub_VirtualNetwork.outputs.bastion_SubnetID
    location: location
    bastion_name: 'Hub_bastion'
  }
}

module Hub_DnsPrivateResolver '../../modules/Microsoft.Network/DNSPrivateResolver.bicep' = {
  name: 'Hub_DNSPrivateResolver'
  params: {
    dnsPrivateResolver_Name: 'Hub_DNSPrivateResolver'
    dnsPrivateResolver_Inbound_SubnetID: Hub_VirtualNetwork.outputs.privateResolver_Inbound_SubnetID
    dnsPrivateResolver_Outbound_SubnetID: Hub_VirtualNetwork.outputs.privateResolver_Outbound_SubnetID
    location: location
    virtualNetwork_ID: Hub_VirtualNetwork.outputs.virtualNetwork_ID
  }
}

module DnsPrivateResolverForwardingRuleSet '../../modules/Microsoft.Network/DNSPrivateResolverRuleSet.bicep' = {
  name: 'dnsPrivateResolverForwardingRuleSet'
  params: {
    outboundEndpoint_ID: Hub_DnsPrivateResolver.outputs.dnsPrivateResolver_Outbound_Endpoint_ID
    domainName: onpremResolvableDomainName
    location: location
    targetDNSServers: [ {
      port: 53
      ipaddress: OnPrem_WinDnsVm.outputs.networkInterface_PrivateIPAddress
    } ]
    virtualNetwork_IDs: [
      Hub_VirtualNetwork.outputs.virtualNetwork_ID 
      Spoke_VirtualNetwork.outputs.virtualNetwork_ID 
    ]
  }
}

module PrivateDNSZone_AzureVMsDotCom '../../modules/Microsoft.Network/PrivateDNSZone.bicep' = {
  name: 'PrivateDNSZone'
  params: {
    privateDNSZone_Name: privateDNSZone_Name
    virtualNetworkIDs: [Hub_VirtualNetwork.outputs.virtualNetwork_ID, Spoke_VirtualNetwork.outputs.virtualNetwork_ID]
    registrationEnabled: true
  }
}

module PublicDnsZone_TestDotCom '../../modules/Microsoft.Network/DNSZone.bicep' = {
  name: 'DNSZone'
  params: {
    dnsZone_Name: publicDNSZone_Name
  }
}

module OnPrem_VirtualNetwork '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'OnPrem_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.100.0.0/16' // Update the dnsServers if you update the address prefix
    dnsServers: [
      '10.100.0.4' // This must be updated if you update the address prefix
    ]
    location: location
    virtualNetwork_Name: 'OnPrem_VNet'
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
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_DNS.ps1 -Username ${virtualMachine_AdminUsername} -SampleDNSZoneName ${onpremResolvableDomainName} -SampleHostName "a" -SampleARecord "172.16.0.1" -PrivateDNSZone "privatelink.blob.core.windows.net" -ConditionalForwarderIPAddress ${Hub_DnsPrivateResolver.outputs.privateDNSResolver_Inbound_Endpoint_IPAddress}'
  }
}

module OnPrem_WinClientVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'OnPrem-WinClientVM'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: Spoke_VirtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'OnPrem-WinClien'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
  }
  dependsOn: [
    OnPrem_WinDnsVm
  ]
}
