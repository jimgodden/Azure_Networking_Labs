@description('Azure Datacenter location for the source resources')
param SourceLocation string = resourceGroup().location

@description('Azure Datacenter location for the destination resources')
param DestinationLocation string = SourceLocation

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

@description('SKU of the Virtual Network Gateway')
param virtualNetworkGateway_SKU string = 'VpnGw1'

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

@description('Sku name of the Azure Firewall.  Allowed values are Basic, Standard, and Premium')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param azureFirewall_SKU string = 'Basic'

@description('If true, Virtual Networks will be connected via Virtual Network Gateway S2S connection.  If false, Virtual Network Peering will be used instead.')
param isUsingVPN bool = true

@description('If true, an Azure Firewall will be deployed in both source and destination')
param isUsingAzureFirewall bool = true

@description('If true, a Windows VM will be deployed in both source and destination')
param isUsingWindows bool = true

@maxValue(99)
@description('Number of Windows Virtual Machines to deploy in the source side.  This number is irrelevant if not deploying Windows Virtual Machines')
param numberOfSourceSideWindowsVMs int = 1

@maxValue(99)
@description('Number of Windows Virtual Machines to deploy in the destination side.  This number is irrelevant if not deploying Windows Virtual Machines')
param numberOfDestinationSideWindowsVMs int = 1

@description('If true, a Linux VM will be deployed in both source and destination')
param isUsingLinux bool = true

@maxValue(99)
@description('Number of Linux Virtual Machines to deploy in the source side.  This number is irrelevant if not deploying Linux Virtual Machines')
param numberOfSourceSideLinuxVMs  int = 1

@maxValue(99)
@description('Number of Linux Virtual Machines to deploy in the destination side.  This number is irrelevant if not deploying Linux Virtual Machines')
param numberOfDestinationSideLinuxVMs  int = 1

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

// Virtual Networks
module virtualNetwork_Source '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'srcVNET'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: SourceLocation
    virtualNetwork_Name: 'srcVNET'
  }
}

module virtualNetwork_Destination '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'dstVNET'
  params: {
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    location: DestinationLocation
    virtualNetwork_Name: 'dstVNET'
  }
}

module vpn_Gateways_and_Connections '../../../modules/Microsoft.Network/VirtualNetworkGatewaysAndConnections.bicep' = if (isUsingVPN) {
  name: 'vpn_Gateways_and_Connections'
  params: {
    location_VirtualNetworkGateway1: SourceLocation
    asn_VirtualNetworkGateway1: 65530
    name_VirtualNetworkGateway1: 'srcVNG'
    subnetId_VirtualNetworkGateway1: virtualNetwork_Source.outputs.gateway_SubnetID
    location_VirtualNetworkGateway2: DestinationLocation
    asn_VirtualNetworkGateway2: 65531
    name_VirtualNetworkGateway2: 'dstVNG'
    subnetId_VirtualNetworkGateway2: virtualNetwork_Destination.outputs.gateway_SubnetID
    virtualNetworkGateway_SKU: virtualNetworkGateway_SKU
    vpn_SharedKey: vpn_SharedKey
  }
}

module virtualNetworkPeering_Source_to_Destination '../../../modules/Microsoft.Network/VirtualNetworkPeering.bicep' = if (!isUsingVPN) {
  name: 'Source_to_Destination_Peering'
  params: {
    virtualNetwork_Destination_Name: virtualNetwork_Source.outputs.virtualNetwork_Name
    virtualNetwork_Source_Name: virtualNetwork_Destination.outputs.virtualNetwork_Name
  }
  dependsOn: [
    bastion
  ]
}

module sourceVM_Windows '../../../modules/Microsoft.Compute/virtualMachine/Windows/Server2025_General.bicep' = [ for i in range(1, numberOfSourceSideWindowsVMs):  if (isUsingWindows) {
  name: 'srcVMWindows${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: SourceLocation
    subnet_ID: virtualNetwork_Source.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'srcVM-Windows${i}'
    vmSize: virtualMachine_Size
    addPublicIPAddress: false
  }
} ]

module destinationVM_Windows '../../../modules/Microsoft.Compute/virtualMachine/Windows/Server2025_General.bicep' = [ for i in range(1, numberOfDestinationSideWindowsVMs):  if (isUsingWindows) {
  name: 'dstVMWindows${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: DestinationLocation
    subnet_ID: virtualNetwork_Destination.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'dstVM-Windows${i}'
    vmSize: virtualMachine_Size
    addPublicIPAddress: false
  }
} ]

module sourceVM_Linx '../../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = [ for i in range(1, numberOfSourceSideLinuxVMs):  if (isUsingLinux) {
  name: 'srcVMLinux${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: SourceLocation
    networkInterface_Name: 'srcVM-Linux_NIC${i}'
    subnet_ID: virtualNetwork_Source.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'srcVM-Linux${i}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'Ubuntu20_DNS_Config.sh'
    commandToExecute: './Ubuntu20_DNS_Config.sh'
  }
} ]

module destinationVMLinx '../../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = [ for i in range(1, numberOfDestinationSideLinuxVMs):  if (isUsingLinux) {
  name: 'dstVMLinux${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: DestinationLocation
    networkInterface_Name: 'dstVM-Linux_NIC${i}'
    subnet_ID: virtualNetwork_Destination.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'dstVM-Linux${i}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'Ubuntu20_WebServer_Config.sh'
    commandToExecute: './Ubuntu20_WebServer_Config.sh'
  }
} ]

module sourceAzFW '../../../modules/Microsoft.Network/AzureFirewall.bicep' = if (isUsingAzureFirewall) {
  name: 'srcAzFW'
  params: {
    azureFirewall_Name: 'srcAzFW'
    azureFirewall_SKU: azureFirewall_SKU
    azureFirewall_ManagementSubnet_ID: virtualNetwork_Source.outputs.azureFirewallManagement_SubnetID
    azureFirewallPolicy_Name: 'srcAzFW_Policy'
    azureFirewall_Subnet_ID: virtualNetwork_Source.outputs.azureFirewall_SubnetID
    location: SourceLocation
  }
  dependsOn: isUsingVPN ? [ vpn_Gateways_and_Connections ] : []
}

module destinationAzFW '../../../modules/Microsoft.Network/AzureFirewall.bicep' = if (isUsingAzureFirewall) {
  name: 'dstAzFW'
  params: {
    azureFirewall_Name: 'dstAzFW'
    azureFirewall_SKU: azureFirewall_SKU
    azureFirewall_ManagementSubnet_ID: virtualNetwork_Destination.outputs.azureFirewallManagement_SubnetID
    azureFirewallPolicy_Name: 'dstAzFW_Policy'
    azureFirewall_Subnet_ID: virtualNetwork_Destination.outputs.azureFirewall_SubnetID
    location: DestinationLocation
  }
  dependsOn: isUsingVPN ? [ vpn_Gateways_and_Connections ] : []
}

module bastion  '../../../modules/Microsoft.Network/BastionEverything.bicep' = {
  name: 'AllBastionResources'
  params: {
    location: SourceLocation
    bastion_name: 'bastion'
    peered_VirtualNetwork_Ids: [
      virtualNetwork_Source.outputs.virtualNetwork_ID
      virtualNetwork_Destination.outputs.virtualNetwork_ID
    ]
    virtualNetwork_AddressPrefix: '10.200.0.0/16'
  }
}
