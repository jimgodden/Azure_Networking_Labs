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

@description('Name of the Private DNS Zone that the Virtual Networks will be registered with.')
param privateDNSZone_Name string = 'azure-contoso.com'

param tagValues object = {
  Training: 'PrivateResolver_Distributed-Complete'
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

module SpokeA_VirtualNetwork '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'SpokeA_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    location: location
    virtualNetwork_Name: 'SpokeA_VNet'
    tagValues: tagValues
  }
}

module SpokeB_VirtualNetwork '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'SpokeB_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.2.0.0/16'
    location: location
    virtualNetwork_Name: 'SpokeB_VNet'
    tagValues: tagValues
  }
}

module Hub_To_SpokeA_Peering '../../modules/Microsoft.Network/VirtualNetworkPeeringSpoke2Spoke.bicep' = {
  name: 'HubToSpokeAPeering'
  params: {
    virtualNetwork1_Name: Hub_VirtualNetwork.outputs.virtualNetwork_Name
    virtualNetwork2_Name: SpokeA_VirtualNetwork.outputs.virtualNetwork_Name
  }
}

module Hub_To_SpokeB_Peering '../../modules/Microsoft.Network/VirtualNetworkPeeringSpoke2Spoke.bicep' = {
  name: 'HubToSpokeBPeering'
  params: {
    virtualNetwork1_Name: Hub_VirtualNetwork.outputs.virtualNetwork_Name
    virtualNetwork2_Name: SpokeB_VirtualNetwork.outputs.virtualNetwork_Name
  }
  dependsOn: [
    Hub_To_SpokeA_Peering
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
    tagValues: tagValues
  }
}

module SpokeA_WinClientVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'SpokeA-WinClientVM'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: SpokeA_VirtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'SpokeA-WinClien'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
    tagValues: tagValues
  }
  dependsOn: [
    Hub_To_SpokeA_Peering
  ]
}

module SpokeB_WinClientVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'SpokeB-WinClientVM'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: SpokeB_VirtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'SpokeB-WinClien'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
    tagValues: tagValues
  }
  dependsOn: [
    Hub_To_SpokeB_Peering
  ]
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

module Hub_DnsPrivateResolver '../../modules/Microsoft.Network/DNSPrivateResolver.bicep' = {
  name: 'Hub_DNSPrivateResolver'
  params: {
    dnsPrivateResolver_Name: 'Hub_DNSPrivateResolver'
    dnsPrivateResolver_Inbound_SubnetID: Hub_VirtualNetwork.outputs.privateResolver_Inbound_SubnetID
    dnsPrivateResolver_Outbound_SubnetID: Hub_VirtualNetwork.outputs.privateResolver_Outbound_SubnetID
    location: location
    virtualNetwork_ID: Hub_VirtualNetwork.outputs.virtualNetwork_ID
    tagValues: tagValues
  }
}

module DnsPrivateResolverForwardingRuleSet '../../modules/Microsoft.Network/DNSPrivateResolverRuleSet.bicep' = {
  name: 'dnsPrivateResolverForwardingRuleSet'
  params: {
    outboundEndpoint_ID: Hub_DnsPrivateResolver.outputs.dnsPrivateResolver_Outbound_Endpoint_ID
    domainName: '${privateDNSZone_Name}.' // Domain names must have a trailing dot
    location: location
    targetDNSServers: [ {
      port: 53
      ipaddress: Hub_DnsPrivateResolver.outputs.privateDNSResolver_Inbound_Endpoint_IPAddress
    } ]
    virtualNetwork_IDs: [
      SpokeA_VirtualNetwork.outputs.virtualNetwork_ID
      SpokeB_VirtualNetwork.outputs.virtualNetwork_ID
    ]
    tagValues: tagValues
  }
}

module PrivateDNSZone_AzureVMsDotCom '../../modules/Microsoft.Network/PrivateDNSZone.bicep' = {
  name: 'PrivateDNSZone'
  params: {
    privateDNSZone_Name: privateDNSZone_Name
    virtualNetworkIDs: [ 
      Hub_VirtualNetwork.outputs.virtualNetwork_ID 
    ]
    registrationEnabled: true
    tagValues: tagValues
  }
}
