// ============================================================================
// VM Single VNet Lab - Azure Networking Sandbox
// ============================================================================
// This template deploys source and destination VMs in a SINGLE VNet for testing
// VM-to-VM connectivity without VNet peering costs. Uses NAT Gateway for outbound.
//
// Architecture:
//   +--------------------------------------------------+
//   |                    VNet (10.0.0.0/16)            |
//   |                                                  |
//   |  +------------+              +------------+      |
//   |  | srcSubnet  |              | dstSubnet  |      |
//   |  | 10.0.0.0/24|              | 10.0.1.0/24|      |
//   |  |  Source VMs|              |  Dest VMs  |      |
//   |  +-----+------+              +------+-----+      |
//   |        |                            |            |
//   |        +---------- NAT GW ----------+            |
//   |                                                  |
//   |  +------------------------+                      |
//   |  | AzureFirewallSubnet    | (optional)           |
//   |  | 10.0.100.0/26          |                      |
//   |  +------------------------+                      |
//   +--------------------------------------------------+
//              |
//          Bastion (10.200.0.0/16)
//
// Cost Benefit:
//   - Traffic between subnets in same VNet = FREE
//   - No VNet peering charges
//
// Optional Components:
//   - Azure Firewall
//   - Custom Script Extensions for VM configuration
// ============================================================================

// ============================================================================
// PARAMETERS - Location & Authentication
// ============================================================================

@description('Azure Datacenter location for all resources')
param location string = 'eastus2'

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param virtualMachine_Size string = 'Standard_D2_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
var acceleratedNetworking = true

// ============================================================================
// PARAMETERS - Optional Components
// ============================================================================

@description('Sku name of the Azure Firewall. Allowed values are Basic, Standard, and Premium')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param azureFirewall_SKU string = 'Basic'

@description('If true, an Azure Firewall will be deployed')
param deployAzureFirewall bool = false

// ============================================================================
// PARAMETERS - Windows Virtual Machines
// Set count to 0 to skip deployment. Custom scripts are optional.
// ============================================================================

@minValue(0)
@maxValue(99)
@description('Number of Windows Virtual Machines to deploy in the source subnet. Set to 0 to skip.')
param numberOfSourceWindowsVMs int = 0

@description('URL to the PowerShell script file for source Windows VMs. Leave empty to skip.')
param sourceWindowsVMScriptFile string = ''

@description('PowerShell command to execute on source Windows VMs. Leave empty to skip.')
param sourceWindowsVMScriptCommand string = ''

@minValue(0)
@maxValue(99)
@description('Number of Windows Virtual Machines to deploy in the destination subnet. Set to 0 to skip.')
param numberOfDestinationWindowsVMs int = 0

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
@description('Number of Linux Virtual Machines to deploy in the source subnet. Set to 0 to skip.')
param numberOfSourceLinuxVMs int = 0

@description('URL to the shell script file for source Linux VMs. Leave empty to skip.')
param sourceLinuxVMScriptFile string = ''

@description('Shell command to execute on source Linux VMs. Leave empty to skip.')
param sourceLinuxVMScriptCommand string = ''

@minValue(0)
@maxValue(99)
@description('Number of Linux Virtual Machines to deploy in the destination subnet. Set to 0 to skip.')
param numberOfDestinationLinuxVMs int = 0

@description('URL to the shell script file for destination Linux VMs. Leave empty to skip.')
param destinationLinuxVMScriptFile string = ''

@description('Shell command to execute on destination Linux VMs. Leave empty to skip.')
param destinationLinuxVMScriptCommand string = ''

// ============================================================================
// VIRTUAL NETWORK - Single VNet with Subnets
// All traffic between subnets is FREE (no peering costs)
// ============================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: 'vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'srcSubnet'
        properties: {
          addressPrefix: '10.0.0.0/24'
          natGateway: {
            id: natGateway.id
          }
        }
      }
      {
        name: 'dstSubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          natGateway: {
            id: natGateway.id
          }
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.0.100.0/26'
        }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties: {
          addressPrefix: '10.0.100.64/26'
        }
      }
    ]
  }
}

// ============================================================================
// NAT GATEWAY - Outbound Internet Access
// Provides consistent outbound IP for all VMs in src and dst subnets
// ============================================================================

resource natGatewayPIP 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: 'natGateway-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2024-01-01' = {
  name: 'natGateway'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: natGatewayPIP.id
      }
    ]
  }
}

// ============================================================================
// BASTION HOST - Secure Access
// Provides secure RDP/SSH access to all VMs without requiring public IPs
// Deployed in its own VNet and peered to the main VNet
// ============================================================================

module bastion '../../../modules/Microsoft.Network/BastionEverything.bicep' = {
  name: 'AllBastionResources'
  params: {
    location: location
    bastion_name: 'bastion'
    peered_VirtualNetwork_Ids: [
      vnet.id
    ]
    virtualNetwork_AddressPrefix: '10.200.0.0/16'
  }
}

// ============================================================================
// AZURE FIREWALL (Optional) - Network Security
// Deploy for centralized traffic inspection and filtering
// ============================================================================

module azureFirewall '../../../modules/Microsoft.Network/AzureFirewall.bicep' = if (deployAzureFirewall) {
  name: 'azureFirewall'
  params: {
    azureFirewall_Name: 'azfw'
    azureFirewall_SKU: azureFirewall_SKU
    azureFirewall_ManagementSubnet_ID: vnet.properties.subnets[3].id // AzureFirewallManagementSubnet
    azureFirewallPolicy_Name: 'azfw-policy'
    azureFirewall_Subnet_ID: vnet.properties.subnets[2].id // AzureFirewallSubnet
    location: location
  }
}

// ============================================================================
// VIRTUAL MACHINES - Workloads
// Source VMs deploy to srcSubnet (10.0.0.0/24)
// Destination VMs deploy to dstSubnet (10.0.1.0/24)
// Traffic between subnets is FREE - no peering costs!
// ============================================================================

// ----- SOURCE WINDOWS VMs -----
module sourceVM_Windows '../../../modules/Microsoft.Compute/virtualMachine/Windows/Server20XX_Default.bicep' = [ for i in range(1, numberOfSourceWindowsVMs): {
  name: 'srcVMWindows${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: vnet.properties.subnets[0].id // srcSubnet
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'srcVM-Win${i}'
    vmSize: virtualMachine_Size
    addPublicIPAddress: false // Using NAT Gateway
    scriptFileUri: sourceWindowsVMScriptFile
    commandToExecute: sourceWindowsVMScriptCommand
  }
} ]

// ----- DESTINATION WINDOWS VMs -----
module destinationVM_Windows '../../../modules/Microsoft.Compute/virtualMachine/Windows/Server20XX_Default.bicep' = [ for i in range(1, numberOfDestinationWindowsVMs): {
  name: 'dstVMWindows${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: vnet.properties.subnets[1].id // dstSubnet
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'dstVM-Win${i}'
    vmSize: virtualMachine_Size
    addPublicIPAddress: false // Using NAT Gateway
    scriptFileUri: destinationWindowsVMScriptFile
    commandToExecute: destinationWindowsVMScriptCommand
  }
} ]

// ----- SOURCE LINUX VMs (Ubuntu 24.04 LTS) -----
module sourceVM_Linux '../../../modules/Microsoft.Compute/VirtualMachine/Linux/Ubuntu24_Default.bicep' = [ for i in range(1, numberOfSourceLinuxVMs): {
  name: 'srcVMLinux${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    networkInterface_Name: 'srcVM-Linux${i}-nic'
    subnet_ID: vnet.properties.subnets[0].id // srcSubnet
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'srcVM-Linux${i}'
    virtualMachine_Size: virtualMachine_Size
    scriptFileUri: sourceLinuxVMScriptFile
    commandToExecute: sourceLinuxVMScriptCommand
  }
} ]

// ----- DESTINATION LINUX VMs (Ubuntu 24.04 LTS) -----
module destinationVM_Linux '../../../modules/Microsoft.Compute/VirtualMachine/Linux/Ubuntu24_Default.bicep' = [ for i in range(1, numberOfDestinationLinuxVMs): {
  name: 'dstVMLinux${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    networkInterface_Name: 'dstVM-Linux${i}-nic'
    subnet_ID: vnet.properties.subnets[1].id // dstSubnet
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'dstVM-Linux${i}'
    virtualMachine_Size: virtualMachine_Size
    scriptFileUri: destinationLinuxVMScriptFile
    commandToExecute: destinationLinuxVMScriptCommand
  }
} ]
