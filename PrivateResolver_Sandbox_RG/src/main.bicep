@description('Azure Datacenter location for the resources and primary route')
param locationPrimary string = resourceGroup().location

@description('Azure Datacenter location for the alternative route')
param locationSecondary string

@description('Azure Datacenter location for the "On Prem" resources')
param locationOnPrem string

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

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

@description('''DNS Zone to be hosted On Prem and with a forwarding rule on the DNS Private Resolver.
Must end with a period (.)
Example:
contoso.com.''')
param onpremResolvableDomainName string = 'contoso.com.'

// Virtual Networks and Peerings
module virtualNetwork_Transit_primary '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'transit_VNet_primary'
  params: {
    virtualNetwork_AddressPrefix: '10.100.0.0/16'
    location: locationPrimary
    virtualNetwork_Name: 'transit_VNet_primary'
  }
}
module virtualNetwork_Transit_secondary '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'transit_VNet_secondary'
  params: {
    virtualNetwork_AddressPrefix: '10.200.0.0/16'
    location: locationSecondary
    virtualNetwork_Name: 'transit_VNet_secondary'
  }
}
module virtualNetwork_Hub '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'hub_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.110.0.0/16'
    location: locationPrimary
    virtualNetwork_Name: 'hub_VNet'
  }
}
module virtualNetwork_Spoke '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'spoke_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.111.0.0/16'
    location: locationPrimary
    virtualNetwork_Name: 'spoke_VNet'
  }
}
module transitPrimary_To_Hub_Peering '../../modules/Microsoft.Network/VirtualNetworkPeeringHub2Spoke.bicep' = {
  name: 'transitPrimaryToHubPeering'
  params: {
    virtualNetwork_Hub_Name: virtualNetwork_Transit_primary.outputs.virtualNetwork_Name
    virtualNetwork_Spoke_Name: virtualNetwork_Hub.outputs.virtualNetwork_Name
  }
  dependsOn: [
    TransitPrimary_to_OnPrem_conn
    OnPrem_to_TransitPrimary_conn
  ]
}
module hub_to_Spoke_Peering '../../modules/Microsoft.Network/VirtualNetworkPeeringSpoke2Spoke.bicep' = {
  name: 'hubPrimaryTospokePeering'
  params: {
    virtualNetwork1_Name: virtualNetwork_Hub.outputs.virtualNetwork_Name
    virtualNetwork2_Name: virtualNetwork_Spoke.outputs.virtualNetwork_Name
  }
}

// Azure Firewall and UDRs to force traffic through it
module azureFirewall '../../modules/Microsoft.Network/AzureFirewall.bicep' = {
  name: 'hubAzFW'
  params: {
    azureFirewall_Name: 'hubAzFW'
    azureFirewall_SKU: 'Basic'
    azureFirewall_ManagementSubnet_ID: virtualNetwork_Hub.outputs.azureFirewallManagement_SubnetID
    azureFirewallPolicy_Name: 'hubAzFW_Policy'
    azureFirewall_Subnet_ID: virtualNetwork_Hub.outputs.azureFirewall_SubnetID
    location: locationPrimary
  }
  dependsOn: [
    virtualNetworkGateway_Transit_Primary
  ]
}
module udrToAzFW_TransitPrimary '../../modules/Microsoft.Network/RouteTable.bicep' = {
  name: 'udrToAzFW_TransitPrimary'
  params: {
    addressPrefixs: [
      virtualNetwork_Hub.outputs.virtualNetwork_AddressPrefix
      virtualNetwork_Spoke.outputs.virtualNetwork_AddressPrefix
      virtualNetwork_OnPremHub.outputs.virtualNetwork_AddressPrefix
    ]
    nextHopType: 'VirtualAppliance'
    routeTable_Name: virtualNetwork_Transit_primary.outputs.routeTable_Name
    routeTableRoute_Name: 'toAzFW'
    nextHopIpAddress: azureFirewall.outputs.azureFirewall_PrivateIPAddress
  }
  dependsOn: [
    azureFirewall
  ]
}
module udrToAzFW_TransitSecondary '../../modules/Microsoft.Network/RouteTable.bicep' = {
  name: 'udrToAzFW_TransitSecondary'
  params: {
    addressPrefixs: [
      virtualNetwork_Hub.outputs.virtualNetwork_AddressPrefix
      virtualNetwork_Spoke.outputs.virtualNetwork_AddressPrefix
      virtualNetwork_OnPremHub.outputs.virtualNetwork_AddressPrefix
    ]
    nextHopType: 'VirtualAppliance'
    routeTable_Name: virtualNetwork_Transit_primary.outputs.routeTable_Name
    routeTableRoute_Name: 'toAzFW'
    nextHopIpAddress: azureFirewall.outputs.azureFirewall_PrivateIPAddress
  }
  dependsOn: [
    azureFirewall
  ]
}
module udrToAzFW_Hub '../../modules/Microsoft.Network/RouteTable.bicep' = {
  name: 'udrToAzFW_Hub'
  params: {
    addressPrefixs: [
      virtualNetwork_Spoke.outputs.virtualNetwork_AddressPrefix
      virtualNetwork_Transit_primary.outputs.virtualNetwork_AddressPrefix
      virtualNetwork_Transit_secondary.outputs.virtualNetwork_AddressPrefix
      virtualNetwork_OnPremHub.outputs.virtualNetwork_AddressPrefix
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
module udrToAzFW_Spoke '../../modules/Microsoft.Network/RouteTable.bicep' = {
  name: 'udrToAzFW_Spoke'
  params: {
    addressPrefixs: [
      virtualNetwork_Hub.outputs.virtualNetwork_AddressPrefix
      virtualNetwork_Transit_primary.outputs.virtualNetwork_AddressPrefix
      virtualNetwork_Transit_secondary.outputs.virtualNetwork_AddressPrefix
      virtualNetwork_OnPremHub.outputs.virtualNetwork_AddressPrefix
    ]
    nextHopType: 'VirtualAppliance'
    routeTable_Name: virtualNetwork_Spoke.outputs.routeTable_Name
    routeTableRoute_Name: 'toAzFW'
    nextHopIpAddress: azureFirewall.outputs.azureFirewall_PrivateIPAddress
  }
  dependsOn: [
    azureFirewall
  ]
}


module spoke_WinVM_client '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'spoke-WinVM-client'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationPrimary
    subnet_ID: virtualNetwork_Spoke.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'spoke-client-VM'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}

module hubBastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'hubBastion'
  params: {
    bastion_SubnetID: virtualNetwork_Hub.outputs.bastion_SubnetID
    location: locationPrimary
    bastion_name: 'hub_bastion'
  }
}

module dnsPrivateResolver '../../modules/Microsoft.Network/DNSPrivateResolver.bicep' = {
  name: 'dnsPrivateResolver'
  params: {
    dnsPrivateResolver_Name: 'hub_DNSPrivateResolver'
    dnsPrivateResolver_Inbound_SubnetID: virtualNetwork_Hub.outputs.privateResolver_Inbound_SubnetID
    dnsPrivateResolver_Outbound_SubnetID: virtualNetwork_Hub.outputs.privateResolver_Outbound_SubnetID
    location: locationPrimary
    virtualNetwork_ID: virtualNetwork_Hub.outputs.virtualNetwork_ID
  }
}

module dnsPrivateResolverForwardingRuleSet '../../modules/Microsoft.Network/DNSPrivateResolverRuleSet.bicep' = {
  name: 'dnsPrivateResolverForwardingRuleSet'
  params: {
    outboundEndpoint_ID: dnsPrivateResolver.outputs.dnsPrivateResolver_Outbound_Endpoint_ID
    domainName: onpremResolvableDomainName
    location: locationPrimary
    targetDNSServers: [for i in range(0, 2): {
      port: 53
      ipaddress: OnPremVM_WinDNS[i].outputs.networkInterface_PrivateIPAddress
    }]
    virtualNetwork_IDs: [
      virtualNetwork_Spoke.outputs.virtualNetwork_ID
    ]
  }
}

module virtualNetwork_OnPremHub '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'onprem_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: locationOnPrem
    virtualNetwork_Name: 'onprem_VNet'
  }
}

// DNS Servers for "On Prem"
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
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_DNS.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_DNS.ps1 -Username ${virtualMachine_AdminUsername} -SampleDNSZoneName ${onpremResolvableDomainName} -SampleHostName "a" -SampleARecord "172.16.0.1" -PrivateDNSZone "privatelink.blob.core.windows.net" -ConditionalForwarderIPAddress ${dnsPrivateResolver.outputs.privateDNSResolver_Inbound_Endpoint_IPAddress}'
  }
} ]

// Virtual Network Gateways for On Prem, Primary Transit, and Secondary Transit
module virtualNetworkGateway_OnPrem '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'OnPremVirtualNetworkGateway'
  params: {
    location: locationOnPrem
    virtualNetworkGateway_ASN: 65000
    virtualNetworkGateway_Name: 'OnPrem_VNG'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork_OnPremHub.outputs.gateway_SubnetID
  }
}
module virtualNetworkGateway_Transit_Primary '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'TransitPrimaryVirtualNetworkGateway'
  params: {
    location: locationPrimary
    virtualNetworkGateway_ASN: 65001
    virtualNetworkGateway_Name: 'Transit_Primary_VNG'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork_Transit_primary.outputs.gateway_SubnetID
  }
}
module virtualNetworkGateway_Transit_Secondary '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'TransitSecondaryVirtualNetworkGateway'
  params: {
    location: locationSecondary
    virtualNetworkGateway_ASN: 65002
    virtualNetworkGateway_Name: 'Transit_Secondary_VNG'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork_Transit_secondary.outputs.gateway_SubnetID
  }
}


// Primary to On Prem S2S Connections
module OnPrem_to_TransitPrimary_conn '../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'OnPrem_to_TransitPrimary_conn'
  params: {
    location: locationOnPrem
    virtualNetworkGateway_ID: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_ASN: virtualNetworkGateway_Transit_Primary.outputs.virtualNetworkGateway_ASN
    vpn_Destination_BGPIPAddress: virtualNetworkGateway_Transit_Primary.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_Name: virtualNetworkGateway_Transit_Primary.outputs.virtualNetworkGateway_Name
    vpn_Destination_PublicIPAddress: virtualNetworkGateway_Transit_Primary.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
  }
}
module TransitPrimary_to_OnPrem_conn '../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'TransitPrimary_to_OnPrem_conn'
  params: {
    location: locationPrimary
    virtualNetworkGateway_ID: virtualNetworkGateway_Transit_Primary.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_ASN: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_ASN
    vpn_Destination_BGPIPAddress: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_Name: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_Name
    vpn_Destination_PublicIPAddress: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
    lngOptionalTag: 'Primary'
  }
}


// Secondary to On Prem S2S Connections
module OnPrem_to_TransitSecondary_conn '../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'OnPrem_to_TransitSecondary_conn'
  params: {
    location: locationOnPrem
    virtualNetworkGateway_ID: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_ASN: virtualNetworkGateway_Transit_Secondary.outputs.virtualNetworkGateway_ASN
    vpn_Destination_BGPIPAddress: virtualNetworkGateway_Transit_Secondary.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_Name: virtualNetworkGateway_Transit_Secondary.outputs.virtualNetworkGateway_Name
    vpn_Destination_PublicIPAddress: virtualNetworkGateway_Transit_Secondary.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
  }
}
module TransitSecondary_to_OnPrem_conn '../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'TransitSecondary_to_OnPrem_conn'
  params: {
    location: locationSecondary
    virtualNetworkGateway_ID: virtualNetworkGateway_Transit_Secondary.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_ASN: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_ASN
    vpn_Destination_BGPIPAddress: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_Name: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_Name
    vpn_Destination_PublicIPAddress: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
    lngOptionalTag: 'Secondary'
  }
}
