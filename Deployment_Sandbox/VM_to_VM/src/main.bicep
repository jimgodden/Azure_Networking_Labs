// ============================================================================
// VM to VM Lab - Azure Networking Sandbox
// ============================================================================
// This template deploys a source and destination environment for testing
// VM-to-VM connectivity across Azure regions. Supports Windows and Linux VMs
// with optional VPN Gateway or VNet Peering connectivity.
//
// Architecture:
//   Source VNet (10.0.0.0/16) <---> Destination VNet (10.1.0.0/16)
//                    |                          |
//              Source VMs                 Destination VMs
//                    |                          |
//                    +-------- Bastion ---------+
//
// Connectivity Options:
//   - VNet Peering (default, fast, low latency)
//   - VPN Gateway S2S (simulates on-prem connectivity)
//
// Optional Components:
//   - Azure Firewall (source and/or destination)
//   - Custom Script Extensions for VM configuration
// ============================================================================

// ============================================================================
// PARAMETERS - Location & Authentication
// ============================================================================

@description('Azure Datacenter location for the source resources')
param SourceLocation string = 'eastus2'

@description('Azure Datacenter location for the destination resources')
param DestinationLocation string = 'westus2'

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param virtualMachine_Size string = 'Standard_D2_v5' // 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
var acceleratedNetworking bool = true // Setting this to a var and true to simplify deployment

// ============================================================================
// PARAMETERS - Connectivity Options (VPN vs Peering)
// ============================================================================

@description('If true, Virtual Networks will be connected via Virtual Network Gateway S2S connection.  If false, Virtual Network Peering will be used instead.')
param isUsingVPN bool = false

@description('SKU of the Virtual Network Gateway')
param virtualNetworkGateway_SKU string = 'VpnGw1AZ'

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

// ============================================================================
// PARAMETERS - Azure Firewall (Optional)
// ============================================================================

@description('Sku name of the Azure Firewall.  Allowed values are Basic, Standard, and Premium')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param azureFirewall_SKU string = 'Basic'

@description('If true, an Azure Firewall will be deployed in source')
param deployAzureFirewall_Source bool = false

@description('If true, an Azure Firewall will be deployed in destination')
param deployAzureFirewall_Destination bool = false

// ============================================================================
// PARAMETERS - Windows Virtual Machines
// Set count to 0 to skip deployment. Custom scripts are optional.
// ============================================================================

@minValue(0)
@maxValue(99)
@description('Number of Windows Virtual Machines to deploy in the source side. Set to 0 to skip.')
param numberOfSourceSideWindowsVMs int = 0

@description('URL to the PowerShell script file for source Windows VMs. Leave empty to skip.')
param sourceWindowsVMScriptFile string = ''

@description('PowerShell command to execute on source Windows VMs. Leave empty to skip.')
param sourceWindowsVMScriptCommand string = ''

@minValue(0)
@maxValue(99)
@description('Number of Windows Virtual Machines to deploy in the destination side. Set to 0 to skip.')
param numberOfDestinationSideWindowsVMs int = 0

@description('URL to the PowerShell script file for destination Windows VMs. Leave empty to skip.')
param destinationWindowsVMScriptFile string = ''

@description('PowerShell command to execute on destination Windows VMs. Leave empty to skip.')
param destinationWindowsVMScriptCommand string = ''

// ============================================================================
// PARAMETERS - Linux Virtual Machines
// Set count to 0 to skip deployment. Custom scripts are optional.
// ============================================================================

@minValue(0)
@maxValue(99)
@description('Number of Linux Virtual Machines to deploy in the source side. Set to 0 to skip.')
param numberOfSourceSideLinuxVMs int = 0

@description('URL to the shell script file for source Linux VMs. Leave empty to skip.')
param sourceLinuxVMScriptFile string = ''

@description('Shell command to execute on source Linux VMs. Leave empty to skip.')
param sourceLinuxVMScriptCommand string = ''

@minValue(0)
@maxValue(99)
@description('Number of Linux Virtual Machines to deploy in the destination side. Set to 0 to skip.')
param numberOfDestinationSideLinuxVMs int = 0

@description('URL to the shell script file for destination Linux VMs. Leave empty to skip.')
param destinationLinuxVMScriptFile string = ''

@description('Shell command to execute on destination Linux VMs. Leave empty to skip.')
param destinationLinuxVMScriptCommand string = ''

// ============================================================================
// VIRTUAL NETWORKS - Foundational Infrastructure
// Source: 10.0.0.0/16 | Destination: 10.1.0.0/16
// These must be deployed first as all other resources depend on them
// ============================================================================

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

// ============================================================================
// BASTION HOST - Secure Access
// Provides secure RDP/SSH access to all VMs without requiring public IPs
// Deployed in its own VNet (10.200.0.0/16) and peered to both src/dst VNets
// Must be deployed before VNet Peering (peering depends on bastion module)
// ============================================================================

module bastion '../../../modules/Microsoft.Network/BastionEverything.bicep' = {
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

// ============================================================================
// CONNECTIVITY - VPN Gateway OR VNet Peering (mutually exclusive)
// Only one option is deployed based on isUsingVPN parameter
// ============================================================================

// Option 1: VPN Gateway S2S Connection (when isUsingVPN = true)
// Simulates on-premises connectivity with BGP-enabled gateways
// Takes ~30 minutes to deploy due to gateway provisioning time
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

// Option 2: VNet Peering (when isUsingVPN = false)
// Fast, low-latency connectivity using Azure backbone (deploys in seconds)
// Note: dependsOn bastion because BastionEverything module creates its own peerings
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

// ============================================================================
// AZURE FIREWALL (Optional) - Network Security
// Deploy in source and/or destination for centralized traffic inspection
// Must wait for VPN Gateway if using VPN (concurrent subnet operations conflict)
// ============================================================================

module sourceAzFW '../../../modules/Microsoft.Network/AzureFirewall.bicep' = if (deployAzureFirewall_Source) {
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

module destinationAzFW '../../../modules/Microsoft.Network/AzureFirewall.bicep' = if (deployAzureFirewall_Destination) {
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

// ============================================================================
// VIRTUAL MACHINES - Workloads
// VMs are deployed after networking is established
// Set count to 0 to skip any VM type. Custom scripts are optional.
// ============================================================================

// ----- SOURCE WINDOWS VMs -----
module sourceVM_Windows '../../../modules/Microsoft.Compute/virtualMachine/Windows/Server20XX_Default.bicep' = [ for i in range(1, numberOfSourceSideWindowsVMs): {
  name: 'srcVMWindows${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: SourceLocation
    subnet_ID: virtualNetwork_Source.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'srcVM-Windows${i}'
    vmSize: virtualMachine_Size
    addPublicIPAddress: true
    scriptFileUri: sourceWindowsVMScriptFile
    commandToExecute: sourceWindowsVMScriptCommand
  }
} ]

// ----- DESTINATION WINDOWS VMs -----
module destinationVM_Windows '../../../modules/Microsoft.Compute/virtualMachine/Windows/Server20XX_Default.bicep' = [ for i in range(1, numberOfDestinationSideWindowsVMs): {
  name: 'dstVMWindows${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: DestinationLocation
    subnet_ID: virtualNetwork_Destination.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'dstVM-Windows${i}'
    vmSize: virtualMachine_Size
    addPublicIPAddress: true
    scriptFileUri: destinationWindowsVMScriptFile
    commandToExecute: destinationWindowsVMScriptCommand
  }
} ]

// ----- SOURCE LINUX VMs (Ubuntu 24.04 LTS) -----
module sourceVM_Linux '../../../modules/Microsoft.Compute/VirtualMachine/Linux/Ubuntu24_Default.bicep' = [ for i in range(1, numberOfSourceSideLinuxVMs): {
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
    scriptFileUri: sourceLinuxVMScriptFile
    commandToExecute: sourceLinuxVMScriptCommand
  }
} ]

// ----- DESTINATION LINUX VMs (Ubuntu 24.04 LTS) -----
module destinationVMLinux '../../../modules/Microsoft.Compute/VirtualMachine/Linux/Ubuntu24_Default.bicep' = [ for i in range(1, numberOfDestinationSideLinuxVMs): {
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
    scriptFileUri: destinationLinuxVMScriptFile
    commandToExecute: destinationLinuxVMScriptCommand
  }
} ]

