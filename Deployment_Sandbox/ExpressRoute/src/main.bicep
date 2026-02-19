// ============================================================================
// ExpressRoute Lab - Azure Networking Sandbox
// ============================================================================
// This template deploys an ExpressRoute lab environment with simulated 
// "On-Premises" and Azure connectivity via ExpressRoute circuit.
//
// Architecture:
//   "OnPrem" VNet (10.100.0.0/16)        Azure VNet (10.0.0.0/16)
//          |                                      |
//     OnPrem VM                               Azure VM
//          |                                      |
//     ExR Gateway  <---- ExR Circuit ---->   ExR Gateway
//          |                                      |
//          └──────── VNet Peering ────────────────┤
//                          |                      |
//                   Bastion VNet (10.250.0.0/24)  |
//                          |                      |
//                   Centralized Bastion ──────────┘
//
// Note: In a real scenario, the ExpressRoute circuit would be provisioned 
// through a service provider. This lab simulates the Azure-side components.
// Both gateways connect to the same circuit to simulate the connection.
// ============================================================================

// ============================================================================
// PARAMETERS - Location & Authentication
// ============================================================================

@description('Azure Datacenter location for the "OnPrem" resources')
param OnPremLocation string = 'eastus2'

@description('Azure Datacenter location for the Azure resources')
param AzureLocation string = 'eastus2'

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param virtualMachine_Size string = 'Standard_D2_v5'

// ============================================================================
// PARAMETERS - ExpressRoute Configuration
// ============================================================================

@description('SKU of the ExpressRoute Gateway')
@allowed([
  'Standard'
  'HighPerformance'
  'UltraPerformance'
  'ErGw1AZ'
  'ErGw2AZ'
  'ErGw3AZ'
])
param expressRouteGateway_SKU string = 'Standard'

@description('Service Provider name for the ExpressRoute Circuit')
param expressRouteCircuit_ServiceProvider string = 'Megaport'

@description('Peering Location for the ExpressRoute Circuit')
param expressRouteCircuit_PeeringLocation string = 'Dallas'

@description('Bandwidth in Mbps for the ExpressRoute Circuit')
@allowed([
  50
  100
  200
  500
  1000
  2000
  5000
  10000
])
param expressRouteCircuit_BandwidthInMbps int = 50

@description('VLAN ID for Private Peering (100-4094)')
param privatePeeringVlanId int = 100

@description('Primary peer subnet for Private Peering')
param privatePeeringPrimarySubnet string = '192.168.1.0/30'

@description('Secondary peer subnet for Private Peering')
param privatePeeringSecondarySubnet string = '192.168.1.4/30'

@description('Peer ASN for Private Peering')
param privatePeeringPeerASN int = 65001

// ============================================================================
// VIRTUAL NETWORKS - Foundational Infrastructure
// OnPrem: 10.100.0.0/16 | Azure: 10.0.0.0/16
// ============================================================================

module virtualNetwork_OnPrem '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'OnPrem_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.100.0.0/16'
    location: OnPremLocation
    virtualNetwork_Name: 'OnPrem_VNet'
  }
}

module virtualNetwork_Azure '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'Azure_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: AzureLocation
    virtualNetwork_Name: 'Azure_VNet'
  }
}

// ============================================================================
// EXPRESSROUTE CIRCUIT - Shared Circuit for Both Environments
// ============================================================================

module expressRouteCircuit '../../../modules/Microsoft.Network/ExpressRouteCircuit.bicep' = {
  name: 'ExR_Circuit'
  params: {
    location: AzureLocation
    expressRouteCircuit_Name: 'ExR_Circuit'
    serviceProviderName: expressRouteCircuit_ServiceProvider
    peeringLocation: expressRouteCircuit_PeeringLocation
    bandwidthInMbps: expressRouteCircuit_BandwidthInMbps
    skuTier: 'Premium'
    skuFamily: 'UnlimitedData'
    enablePrivatePeering: true
    privatePeeringVlanId: privatePeeringVlanId
    privatePeeringPrimarySubnet: privatePeeringPrimarySubnet
    privatePeeringSecondarySubnet: privatePeeringSecondarySubnet
    privatePeeringPeerASN: privatePeeringPeerASN
  }
}

// ============================================================================
// EXPRESSROUTE GATEWAYS - OnPrem and Azure
// ============================================================================

module expressRouteGateway_OnPrem '../../../modules/Microsoft.Network/ExpressRouteGateway.bicep' = {
  name: 'OnPrem_ExR_Gateway'
  params: {
    location: OnPremLocation
    expressRouteGateway_Name: 'OnPrem_ExR_Gateway'
    expressRouteGateway_SKU: expressRouteGateway_SKU
    gatewaySubnet_ID: virtualNetwork_OnPrem.outputs.gateway_SubnetID
    allowRemoteVnetTraffic: true
  }
}

module expressRouteGateway_Azure '../../../modules/Microsoft.Network/ExpressRouteGateway.bicep' = {
  name: 'Azure_ExR_Gateway'
  params: {
    location: AzureLocation
    expressRouteGateway_Name: 'Azure_ExR_Gateway'
    expressRouteGateway_SKU: expressRouteGateway_SKU
    gatewaySubnet_ID: virtualNetwork_Azure.outputs.gateway_SubnetID
    allowRemoteVnetTraffic: true
  }
}

// ============================================================================
// EXPRESSROUTE CONNECTIONS - Connect Gateways to Circuit
// ============================================================================

module expressRouteConnection_OnPrem '../../../modules/Microsoft.Network/ExpressRouteConnection.bicep' = {
  name: 'OnPrem_ExR_Connection'
  params: {
    location: OnPremLocation
    connection_Name: 'OnPrem_to_ExR_Circuit'
    expressRouteGateway_ID: expressRouteGateway_OnPrem.outputs.expressRouteGateway_ID
    expressRouteCircuit_ID: expressRouteCircuit.outputs.expressRouteCircuit_ID
    routingWeight: 0
  }
}

module expressRouteConnection_Azure '../../../modules/Microsoft.Network/ExpressRouteConnection.bicep' = {
  name: 'Azure_ExR_Connection'
  dependsOn: [
    expressRouteConnection_OnPrem
  ]
  params: {
    location: AzureLocation
    connection_Name: 'Azure_to_ExR_Circuit'
    expressRouteGateway_ID: expressRouteGateway_Azure.outputs.expressRouteGateway_ID
    expressRouteCircuit_ID: expressRouteCircuit.outputs.expressRouteCircuit_ID
    routingWeight: 0
  }
}

// ============================================================================
// BASTION - Centralized Bastion with VNet Peering to Both Environments
// ============================================================================

module bastionEverything '../../../modules/Microsoft.Network/BastionEverything.bicep' = {
  name: 'Centralized_Bastion'
  params: {
    location: AzureLocation
    bastion_name: 'Centralized_Bastion'
    bastion_SKU: 'Standard'
    virtualNetwork_AddressPrefix: '10.250.0.0/24'
    peered_VirtualNetwork_Ids: [
      virtualNetwork_OnPrem.outputs.virtualNetwork_ID
      virtualNetwork_Azure.outputs.virtualNetwork_ID
    ]
  }
}

// ============================================================================
// VIRTUAL MACHINES - Windows VMs in OnPrem and Azure
// ============================================================================

module vm_OnPrem '../../../modules/Microsoft.Compute/VirtualMachine/Windows/Server20XX_Default.bicep' = {
  name: 'OnPrem_VM'
  params: {
    location: OnPremLocation
    virtualMachine_Name: 'OnPrem-VM'
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    vmSize: virtualMachine_Size
    subnet_ID: virtualNetwork_OnPrem.outputs.general_SubnetID
    acceleratedNetworking: true
    windowsServerVersion: '2025-datacenter-azure-edition'
    scriptFileUri: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2025_ConfigScript.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Type General'
  }
}

module vm_Azure '../../../modules/Microsoft.Compute/VirtualMachine/Windows/Server20XX_Default.bicep' = {
  name: 'Azure_VM'
  params: {
    location: AzureLocation
    virtualMachine_Name: 'Azure-VM'
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    vmSize: virtualMachine_Size
    subnet_ID: virtualNetwork_Azure.outputs.general_SubnetID
    acceleratedNetworking: true
    windowsServerVersion: '2025-datacenter-azure-edition'
    scriptFileUri: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2025_ConfigScript.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Type General'
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

output OnPrem_VM_PrivateIP string = vm_OnPrem.outputs.networkInterface_PrivateIPAddress
output Azure_VM_PrivateIP string = vm_Azure.outputs.networkInterface_PrivateIPAddress
output ExpressRoute_ServiceKey string = expressRouteCircuit.outputs.expressRouteCircuit_ServiceKey
output ExpressRoute_ProvisioningState string = expressRouteCircuit.outputs.expressRouteCircuit_ServiceProviderProvisioningState
