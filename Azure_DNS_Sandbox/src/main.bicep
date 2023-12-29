@description('Azure Datacenter location for the Hub and Spoke A resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Password for the Virtual Machine Admin User')
param virtualMachine_Size string = 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

param virtualMachine_ScriptFileLocation string = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/Refactoring/scripts/'

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
param privateDNSZone_Name string = 'AzureVMs.com'

@description('Name of the DNS Zone for public DNS resolution.')
param publicDNSZone_Name string = 'DNSSandboxTest${uniqueString(resourceGroup().id)}.com'

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

@description('''DNS Zone to be hosted On Prem and with a forwarding rule on the DNS Private Resolver.
Must end with a period (.)
Example:
contoso.com.''')
param onpremResolvableDomainName string = 'contoso.com.'

module virtualNetwork_Hub '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'hub_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: location
    virtualNetwork_Name: 'hub_VNet'
  }
}

module virtualNetwork_Spoke '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'spoke_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    dnsServers: [for i in range(0, 2) : hub_WinVMs[i].outputs.networkInterface_PrivateIPAddress]
    location: location
    virtualNetwork_Name: 'spoke_VNet'
  }
}

module hub_To_Spoke_Peering '../../modules/Microsoft.Network/VirtualNetworkPeeringHub2Spoke.bicep' = {
  name: 'hubToSpokePeering'
  params: {
    virtualNetwork_Hub_Name: virtualNetwork_Hub.outputs.virtualNetwork_Name
    virtualNetwork_Spoke_Name: virtualNetwork_Spoke.outputs.virtualNetwork_Name
  }
  dependsOn: [
    Hub_to_OnPrem_conn
    OnPrem_to_Hub_conn
  ]
}

module hub_WinVMs '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = [ for i in range(0, 2) : {
  name: 'hub-WinVM${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'hub-WinVM${i}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_DNS.ps1'
  }
} ]

module spoke_WinVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'spoke-WinVM'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork_Spoke.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'spoke-Web-VM'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_WebServer.ps1'
  }
  dependsOn: [
    hub_To_Spoke_Peering
  ]
}

module spoke_WinVM_client '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'spoke-WinVM-client'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork_Spoke.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'spoke-client-VM'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_WebServer.ps1'
  }
  dependsOn: [
    hub_To_Spoke_Peering
  ]
}

module privateLink '../../modules/Microsoft.Network/PrivateLink.bicep' = {
  name: 'privateLink'
  params: {
    acceleratedNetworking: acceleratedNetworking
    internalLoadBalancer_SubnetID: virtualNetwork_Spoke.outputs.general_SubnetID
    location: location
    networkInterface_IPConfig_Names: [spoke_WinVM.outputs.networkInterface_IPConfig0_Name]
    networkInterface_Names: [spoke_WinVM.outputs.networkInterface_Name]
    networkInterface_SubnetID: virtualNetwork_Spoke.outputs.general_SubnetID
    privateEndpoint_SubnetID: virtualNetwork_Spoke.outputs.privateEndpoint_SubnetID
    privateLink_SubnetID: virtualNetwork_Spoke.outputs.privateLinkService_SubnetID
    privateLink_Name: 'spoke_PrivateLink'
    privateEndpoint_name: 'hub_PrivateEndpoint_to_PrivateLink'
  }
}

module storageAccount '../../modules/Microsoft.Storage/StorageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    location: location
    storageAccount_Name: storageAccount_Name
  }
}

module hub_StorageAccount_Blob_PrivateEndpoint '../../modules/Microsoft.Network/PrivateEndpoint.bicep' = {
  name: 'hub_StorageAccount_Blob_PrivateEndpoint'
  params: {
    fqdn: storageAccount.outputs.storageaccount_Blob_FQDN
    groupID: 'blob'
    location: location
    privateDNSZone_Name: 'privatelink.blob.${environment().suffixes.storage}'
    privateEndpoint_Name: 'hub_${storageAccount_Name}_blob_pe'
    privateEndpoint_SubnetID: virtualNetwork_Hub.outputs.privateEndpoint_SubnetID
    privateLinkServiceId: storageAccount.outputs.storageAccount_ID
    virtualNetwork_IDs: [virtualNetwork_Hub.outputs.virtualNetwork_ID]
  }
}

module hubBastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'hubBastion'
  params: {
    bastion_SubnetID: virtualNetwork_Hub.outputs.bastion_SubnetID
    location: location
    bastion_name: 'hub_bastion'
  }
}

module dnsPrivateResolver '../../modules/Microsoft.Network/DNSPrivateResolver.bicep' = {
  name: 'dnsPrivateResolver'
  params: {
    dnsPrivateResolver_Name: 'hub_DNSPrivateResolver'
    dnsPrivateResolver_Inbound_SubnetID: virtualNetwork_Hub.outputs.privateResolver_Inbound_SubnetID
    dnsPrivateResolver_Outbound_SubnetID: virtualNetwork_Hub.outputs.privateResolver_Outbound_SubnetID
    location: location
    virtualNetwork_ID: virtualNetwork_Hub.outputs.virtualNetwork_ID
  }
}

module dnsPrivateResolverForwardingRuleSet '../../modules/Microsoft.Network/DNSPrivateResolverRuleSet.bicep' = {
  name: 'dnsPrivateResolverForwardingRuleSet'
  params: {
    outboundEndpoint_ID: dnsPrivateResolver.outputs.dnsPrivateResolver_Outbound_Endpoint_ID
    domainName: onpremResolvableDomainName
    location: location
    targetDNSServers: [for i in range(0, 2): {
      port: 53
      ipaddress: OnPremVM_WinDNS[i].outputs.networkInterface_PrivateIPAddress
    }]
    virtualNetwork_IDs: [
      virtualNetwork_Hub.outputs.virtualNetwork_ID 
      virtualNetwork_Spoke.outputs.virtualNetwork_ID 
    ]
  }
}

module privateDNSZone_AzureVMsDotCom '../../modules/Microsoft.Network/PrivateDNSZone.bicep' = {
  name: 'PrivateDNSZone'
  params: {
    privateDNSZone_Name: privateDNSZone_Name
    virtualNetworkIDs: [virtualNetwork_Hub.outputs.virtualNetwork_ID, virtualNetwork_Spoke.outputs.virtualNetwork_ID]
    registrationEnabled: true
  }
}

module dnsZone_TestDotCom '../../modules/Microsoft.Network/DNSZone.bicep' = {
  name: 'DNSZone'
  params: {
    dnsZone_Name: publicDNSZone_Name
  }
}

module virtualNetwork_OnPremHub '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'onprem_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.100.0.0/16'
    location: location
    virtualNetwork_Name: 'onprem_VNet'
  }
}

module OnPremVM_WinDNS '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = [for i in range(0, 2) : {
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
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_DNS.ps1 -SampleDNSZoneName ${onpremResolvableDomainName} -SampleHostName "a" -SampleARecord "172.16.0.1" -PrivateDNSZone "privatelink.blob.core.windows.net" -ConditionalForwarderIPAddress ${dnsPrivateResolver.outputs.privateDNSResolver_Inbound_Endpoint_IPAddress}'
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























