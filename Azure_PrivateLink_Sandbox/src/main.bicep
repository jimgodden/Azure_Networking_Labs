@description('Azure Datacenter location for the Hub and Spoke A resources')
param locationA string = resourceGroup().location

@description('''
Azure Datacenter location for the Spoke B resources.  
Use the same region as locationA if you do not want to test multi-region
''')
param locationB string = locationA

@description('Azure Datacenter location for the "OnPrem" resources')
param locationOnPrem string = locationA

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Password for the Virtual Machine Admin User')
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
param storageAccount_Name string = 'storagepl${uniqueString(resourceGroup().id)}'

@description('Set this to true if you want to use an Azure Firewall in the Hub Virtual Network.')
param usingAzureFirewall bool = true

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

@description('''DNS Zone to be hosted On Prem and with a forwarding rule on the DNS Private Resolver.
Must end with a period (.)
Example:
contoso.com.''')
param onpremResolvableDomainName string = 'contoso.com.'

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'


module virtualNetwork_Hub '../../modules/Microsoft.Network/VirtualNetworkHub.bicep' = {
  name: 'hub_VNet'
  params: {
    // firstTwoOctetsOfVirtualNetworkPrefix: '10.0'
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: locationA
    virtualNetwork_Name: 'hub_VNet'
  }
}

module virtualNetwork_SpokeA '../../modules/Microsoft.Network/VirtualNetworkSpoke.bicep' = {
  name: 'spokeA_VNet'
  params: {
    // firstTwoOctetsOfVirtualNetworkPrefix: '10.1'
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    dnsServers: [for i in range(0, 2) : hub_WinVMs[i].outputs.networkInterface_PrivateIPAddress]
    location: locationA
    virtualNetwork_Name: 'spokeA_VNet'
  }
}

module virtualNetwork_SpokeB '../../modules/Microsoft.Network/VirtualNetworkSpoke.bicep' = {
  name: 'spokeB_VNet'
  params: {
    // firstTwoOctetsOfVirtualNetworkPrefix: '10.2'
    virtualNetwork_AddressPrefix: '10.2.0.0/16'
    dnsServers: [for i in range(0, 2) : hub_WinVMs[i].outputs.networkInterface_PrivateIPAddress]
    location: locationB
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

module hub_WinVMs '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = [ for i in range(0, 2) : {
  name: 'hub-WinVM${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationA
    subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'hub-WinVM${i}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_DNS_InitScript.ps1'
  }
} ]

module spokeA_WinVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'spokeA-WinVM'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationA
    subnet_ID: virtualNetwork_SpokeA.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'spokeA-WinVM'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_General_InitScript.ps1'
  }
  dependsOn: [
    hub_To_SpokeA_Peering
  ]
}

module spokeB_WinVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'spokeB-WinVM'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationB
    subnet_ID: virtualNetwork_SpokeB.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'spokeB-WinVM'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_WebServer_InitScript.ps1'
  }
  dependsOn: [
    hub_To_SpokeB_Peering
  ]
}

module privateLink '../../modules/Microsoft.Network/PrivateLink.bicep' = {
  name: 'privateLink'
  params: {
    acceleratedNetworking: acceleratedNetworking
    internalLoadBalancer_SubnetID: virtualNetwork_SpokeB.outputs.general_SubnetID
    location: locationB
    networkInterface_IPConfig_Names: [spokeB_WinVM.outputs.networkInterface_IPConfig0_Name]
    networkInterface_Names: [spokeB_WinVM.outputs.networkInterface_Name]
    networkInterface_SubnetID: virtualNetwork_SpokeB.outputs.general_SubnetID
    privateEndpoint_SubnetID: virtualNetwork_SpokeB.outputs.privateEndpoint_SubnetID
    privateLink_SubnetID: virtualNetwork_SpokeB.outputs.privateLinkService_SubnetID
    privateLink_Name: 'spokeB_PrivateLink'
    privateEndpoint_name: 'hub_PrivateEndpoint_to_PrivateLink'
  }
}

module storageAccount '../../modules/Microsoft.Storage/StorageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    location: locationB
    storageAccount_Name: storageAccount_Name
  }
}

module hub_StorageAccount_Blob_PrivateEndpoint '../../modules/Microsoft.Network/PrivateEndpoint.bicep' = {
  name: 'hub_StorageAccount_Blob_PrivateEndpoint'
  params: {
    fqdn: storageAccount.outputs.storageaccount_Blob_FQDN
    groupID: 'blob'
    location: locationA
    privateDNSZone_Name: 'privatelink.blob.${environment().suffixes.storage}'
    privateEndpoint_Name: 'hub_${storageAccount_Name}_blob_pe'
    privateEndpoint_SubnetID: virtualNetwork_Hub.outputs.privateEndpoint_SubnetID
    privateLinkServiceId: storageAccount.outputs.storageAccount_ID
    virtualNetwork_IDs: [virtualNetwork_Hub.outputs.virtualNetwork_ID]
  }
}

module azureFirewall '../../modules/Microsoft.Network/AzureFirewall.bicep' = if (usingAzureFirewall) {
  name: 'hubAzureFirewall'
  params: {
    azureFirewall_ManagementSubnet_ID: virtualNetwork_Hub.outputs.azureFirewallManagement_SubnetID
    azureFirewall_Name: 'hub_AzFW'
    azureFirewall_SKU: 'Basic'
    azureFirewall_Subnet_ID: virtualNetwork_Hub.outputs.azureFirewall_SubnetID
    azureFirewallPolicy_Name: 'hub_AzFWPolicy'
    location: locationA
  }
  dependsOn: [
    Hub_to_OnPrem_conn
    OnPrem_to_Hub_conn
  ]
}

module udrToAzFW_Hub '../../modules/Microsoft.Network/RouteTable.bicep' = if (usingAzureFirewall) {
  name: 'udrToAzFW_Hub'
  params: {
    addressPrefixs: [
      virtualNetwork_Hub.outputs.virtualNetwork_AddressPrefix
      virtualNetwork_SpokeA.outputs.virtualNetwork_AddressPrefix
      virtualNetwork_SpokeB.outputs.virtualNetwork_AddressPrefix
    ]
    nextHopType: 'VirtualAppliance'
    routeTable_Name: virtualNetwork_Hub.outputs.routeTable_Name
    routeTableRoute_Name: 'toAzFW'
    nextHopIpAddress: azureFirewall.outputs.azureFirewall_PrivateIPAddress
  }
  dependsOn: [
    azureFirewall
  ]
}

module udrToAzFW_SpokeA '../../modules/Microsoft.Network/RouteTable.bicep' = if (usingAzureFirewall) {
  name: 'udrToAzFW_SpokeA'
  params: {
    addressPrefixs: [
      virtualNetwork_Hub.outputs.virtualNetwork_AddressPrefix
      virtualNetwork_SpokeA.outputs.virtualNetwork_AddressPrefix
      virtualNetwork_SpokeB.outputs.virtualNetwork_AddressPrefix
    ]
    nextHopType: 'VirtualAppliance'
    routeTable_Name: virtualNetwork_SpokeA.outputs.routeTable_Name
    routeTableRoute_Name: 'toAzFW'
    nextHopIpAddress: azureFirewall.outputs.azureFirewall_PrivateIPAddress
  }
  dependsOn: [
    azureFirewall
  ]
}

module udrToAzFW_SpokeB '../../modules/Microsoft.Network/RouteTable.bicep' = if (usingAzureFirewall) {
  name: 'udrToAzFW_SpokeB'
  params: {
    addressPrefixs: [
      virtualNetwork_Hub.outputs.virtualNetwork_AddressPrefix
      virtualNetwork_SpokeA.outputs.virtualNetwork_AddressPrefix
      virtualNetwork_SpokeB.outputs.virtualNetwork_AddressPrefix
    ]
    nextHopType: 'VirtualAppliance'
    routeTable_Name: virtualNetwork_SpokeB.outputs.routeTable_Name
    routeTableRoute_Name: 'toAzFW'
    nextHopIpAddress: azureFirewall.outputs.azureFirewall_PrivateIPAddress
  }
  dependsOn: [
    azureFirewall
  ]
}

module hubBastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'hubBastion'
  params: {
    bastion_SubnetID: virtualNetwork_Hub.outputs.bastion_SubnetID
    location: locationA
    bastion_name: 'hub_bastion'
  }
}

module dnsPrivateResolver '../../modules/Microsoft.Network/DNSPrivateResolver.bicep' = {
  name: 'dnsPrivateResolver'
  params: {
    dnsPrivateResolver_Name: 'hub_DNSPrivateResolver'
    dnsPrivateResolver_Inbound_SubnetID: virtualNetwork_Hub.outputs.privateResolver_Inbound_SubnetID
    dnsPrivateResolver_Outbound_SubnetID: virtualNetwork_Hub.outputs.privateResolver_Outbound_SubnetID
    location: locationA
    virtualNetwork_ID: virtualNetwork_Hub.outputs.virtualNetwork_ID
  }
}

module dnsPrivateResolverForwardingRuleSet '../../modules/Microsoft.Network/DNSPrivateResolverRuleSet.bicep' = {
  name: 'dnsPrivateResolverForwardingRuleSet'
  params: {
    outboundEndpoint_ID: dnsPrivateResolver.outputs.dnsPrivateResolver_Outbound_Endpoint_ID
    domainName: onpremResolvableDomainName
    location: locationA
    targetDNSServers: [for i in range(0, 2): {
      port: 53
      ipaddress: OnPremVM_WinDNS[i].outputs.networkInterface_PrivateIPAddress
    }]
    virtualNetwork_IDs: [
      virtualNetwork_Hub.outputs.virtualNetwork_ID 
      virtualNetwork_SpokeA.outputs.virtualNetwork_ID 
      virtualNetwork_SpokeB.outputs.virtualNetwork_ID
    ]
  }
}

module virtualNetwork_OnPremHub '../../modules/Microsoft.Network/VirtualNetworkHub.bicep' = {
  name: 'onprem_VNet'
  params: {
    // firstTwoOctetsOfVirtualNetworkPrefix: '10.100'
    virtualNetwork_AddressPrefix: '10.100.0.0/16'
    location: locationOnPrem
    virtualNetwork_Name: 'onprem_VNet'
  }
}

module OnPremVM_WinDNS '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = [for i in range(0, 2) : {
  name: 'OnPremWinDNS${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationOnPrem
    subnet_ID: virtualNetwork_OnPremHub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'OnPrem-WinDNS${i}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_DNS_InitScript.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_DNS_InitScript.ps1 -SampleDNSZoneName ${onpremResolvableDomainName} -SampleHostName "a" -SampleARecord "172.16.0.1" -PrivateDNSZone "privatelink.blob.core.windows.net" -ConditionalForwarderIPAddress ${dnsPrivateResolver.outputs.privateDNSResolver_Inbound_Endpoint_IPAddress}'
  }
} ]

module virtualNetworkGateway_OnPrem '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'OnPremVirtualNetworkGateway'
  params: {
    location: locationOnPrem
    virtualNetworkGateway_ASN: 65000
    virtualNetworkGateway_Name: 'OnPrem_VNG'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork_OnPremHub.outputs.gateway_SubnetID
  }
}

module virtualNetworkGateway_Hub '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'HubVirtualNetworkGateway'
  params: {
    location: locationA
    virtualNetworkGateway_ASN: 65001
    virtualNetworkGateway_Name: 'Hub_VNG'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork_Hub.outputs.gateway_SubnetID
  }
}

module OnPrem_to_Hub_conn '../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'OnPrem_to_Hub_conn'
  params: {
    location: locationOnPrem
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
    location: locationOnPrem
    virtualNetworkGateway_ID: virtualNetworkGateway_Hub.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_ASN: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_ASN
    vpn_Destination_BGPIPAddress: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_Name: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_Name
    vpn_Destination_PublicIPAddress: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
  }
}




















