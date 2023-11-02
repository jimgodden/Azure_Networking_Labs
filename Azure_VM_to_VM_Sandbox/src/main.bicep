@description('Azure Datacenter location for the source resources')
param srcLocation string = resourceGroup().location

@description('Azure Datacenter location for the destination resources')
param dstLocation string

@description('Username for the admin account of the Virtual Machines')
param vm_adminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param vm_adminPassword string

@description('Size of the Virtual Machines')
param vmSize string = 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param accelNet bool = false

@description('SKU of the Virtual Network Gateway')
param VNG_SKU string = 'VpnGw1'

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

@description('Sku name of the Azure Firewall.  Allowed values are Basic, Standard, and Premium')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param AzFW_SKU string

@description('If true, Virtual Networks will be connected via Virtual Network Gateway S2S connection.  If false, Virtual Network Peering will be used instead.')
param isUsingVPN bool = true

@description('If true, an Azure Firewall will be deployed in both source and destination')
param isUsingAzureFirewall bool = true

@description('If true, a Windows VM will be deployed in both source and destination')
param isUsingWindows bool = true

@description('Amount of Windows Virtual Machines to deploy in the source side.  This number is irrelevant if not deploying Windows Virtual Machines')
param amountOfSourceSideWindowsVMs int = 1

@description('Amount of Windows Virtual Machines to deploy in the destination side.  This number is irrelevant if not deploying Windows Virtual Machines')
param amountOfDestinationSideWindowsVMs int = 1

@description('If true, a Linux VM will be deployed in both source and destination')
param isUsingLinux bool = true

@description('Amount of Linux Virtual Machines to deploy in the source side.  This number is irrelevant if not deploying Linux Virtual Machines')
param amountOfSourceSideLinuxVMs  int = 1

@description('Amount of Linux Virtual Machines to deploy in the destination side.  This number is irrelevant if not deploying Linux Virtual Machines')
param amountOfDestinationSideLinuxVMs  int = 1

// Virtual Networks
module sourceVNET './Modules/VirtualNetwork.bicep' = {
  name: 'srcVNET'
  params: {
    defaultNSG_Name: 'srcNSG'
    firstTwoOctetsOfVNETPrefix: '10.0'
    location: srcLocation
    routeTable_Name: 'srcRT'
    vnet_Name: 'srcVNET'
  }
}

module destinationVNET './Modules/VirtualNetwork.bicep' = {
  name: 'dstVNET'
  params: {
    defaultNSG_Name: 'dstNSG'
    firstTwoOctetsOfVNETPrefix: '10.1'
    location: dstLocation
    routeTable_Name: 'dstRT'
    vnet_Name: 'dstVNET'
  }
}

// Virtual Network Gateways
module sourceVNG 'Modules/VirtualNetworkGateway.bicep' = if (isUsingVPN) {
  name: 'srcVNG'
  params: {
    location: srcLocation
    VNG_ASN: 65530
    VNG_Name: 'srcVNG'
    VNG_Subnet_ResourceID: sourceVNET.outputs.gatewaySubnetID
    VNG_SKU: VNG_SKU
  }
}

module destinationVNG 'Modules/VirtualNetworkGateway.bicep' = if (isUsingVPN) {
  name: 'dstVNG'
  params: {
    location: dstLocation
    VNG_ASN: 65531
    VNG_Name: 'dstVNG'
    VNG_Subnet_ResourceID: destinationVNET.outputs.gatewaySubnetID
    VNG_SKU: VNG_SKU
  }
}
// Connections to the other Virtual Network Gateway
module sourceVNG_Conn 'Modules/VPNConnection.bicep' = if (isUsingVPN) {
  name: 'srcVNG_conn'
  params: {
    bgpPeeringAddress: destinationVNG.outputs.VNGBGPAddress
    destination_ASN: destinationVNG.outputs.VNGASN
    gatewayIPAddress: destinationVNG.outputs.VNGPIP
    location: srcLocation
    resourceNamePrefix: 'src_to_dst'
    VNGResourceID: sourceVNG.outputs.VNGResourceID
    vpn_SharedKey: vpn_SharedKey
  }
}

module destinationVNG_Conn 'Modules/VPNConnection.bicep' = if (isUsingVPN) {
  name: 'dstVNG_conn'
  params: {
    bgpPeeringAddress: sourceVNG.outputs.VNGBGPAddress
    destination_ASN: sourceVNG.outputs.VNGASN
    gatewayIPAddress: sourceVNG.outputs.VNGPIP
    location: dstLocation
    resourceNamePrefix: 'dst_to_src'
    VNGResourceID: destinationVNG.outputs.VNGResourceID
    vpn_SharedKey: vpn_SharedKey
  }
}

// Virtual Network Peerings
module sourceVNETPeering './Modules/VirtualNetworkPeering.bicep' = if (!isUsingVPN) {
  name: 'srctodstPeering'
  params: {
    dstVNET_Name: destinationVNET.outputs.vnetName
    originVNET_Name: sourceVNET.outputs.vnetName
  }
  dependsOn: [
    sourceBastion
  ]
}

module destinationVNETPeering './Modules/VirtualNetworkPeering.bicep' = if (!isUsingVPN) {
  name: 'dsttosrcPeering'
  params: {
    dstVNET_Name: sourceVNET.outputs.vnetName
    originVNET_Name: destinationVNET.outputs.vnetName
  }
  dependsOn: [
    sourceBastion
  ]
}

// Windows Virtual Machines
module sourceVM_Windows './Modules/NetTestVM.bicep' = [ for i in range(1, amountOfSourceSideWindowsVMs):  if (isUsingWindows) {
  name: 'srcVMWindows${i}'
  params: {
    accelNet: accelNet
    location: srcLocation
    nic_Name: 'srcVM-Windows_NIC${i}'
    subnetID: sourceVNET.outputs.generalSubnetID
    vm_AdminPassword: vm_adminPassword
    vm_AdminUserName: vm_adminUsername
    vm_Name: 'srcVM-Windows${i}'
    vmSize: vmSize
  }
} ]

module destinationVM_Windows './Modules/NetTestVM.bicep' = [ for i in range(1, amountOfDestinationSideWindowsVMs):  if (isUsingWindows) {
  name: 'dstVMWindows${i}'
  params: {
    accelNet: accelNet
    location: dstLocation
    nic_Name: 'dstVM-Windows_NIC${i}'
    subnetID: destinationVNET.outputs.generalSubnetID
    vm_AdminPassword: vm_adminPassword
    vm_AdminUserName: vm_adminUsername
    vm_Name: 'dstVM-Windows${i}'
    vmSize: vmSize
  }
} ]

// Linux Virtual Machines
module sourceVM_Linx 'Modules/LinuxNetTestVM.bicep' = [ for i in range(1, amountOfSourceSideLinuxVMs):  if (isUsingLinux) {
  name: 'srcVMLinux${i}'
  params: {
    accelNet: accelNet
    location: srcLocation
    nic_Name: 'srcVM-Linux_NIC${i}'
    subnetID: sourceVNET.outputs.generalSubnetID
    vm_AdminPassword: vm_adminPassword
    vm_AdminUserName: vm_adminUsername
    vm_Name: 'srcVM-Linux${i}'
    vmSize: vmSize
  }
} ]

module destinationVMLinx 'Modules/LinuxNetTestVM.bicep' = [ for i in range(1, amountOfDestinationSideLinuxVMs):  if (isUsingLinux) {
  name: 'dstVMLinux${i}'
  params: {
    accelNet: accelNet
    location: dstLocation
    nic_Name: 'dstVM-Linux_NIC${i}'
    subnetID: destinationVNET.outputs.generalSubnetID
    vm_AdminPassword: vm_adminPassword
    vm_AdminUserName: vm_adminUsername
    vm_Name: 'dstVM-Linux${i}'
    vmSize: vmSize
  }
} ]

// Azure Firewall
module sourceAzFW 'Modules/AzureFirewall.bicep' = if (isUsingAzureFirewall) {
  name: 'srcAzFW'
  params: {
    AzFW_Name: 'srcAzFW'
    AzFW_SKU: AzFW_SKU
    azfwManagementSubnetID: sourceVNET.outputs.azfwManagementSubnetID
    AzFWPolicy_Name: 'srcAzFW_Policy'
    azfwSubnetID: sourceVNET.outputs.azfwSubnetID
    location: srcLocation
  }
}

module destinationAzFW 'Modules/AzureFirewall.bicep' = if (isUsingAzureFirewall) {
  name: 'dstAzFW'
  params: {
    AzFW_Name: 'dstAzFW'
    AzFW_SKU: AzFW_SKU
    azfwManagementSubnetID: destinationVNET.outputs.azfwManagementSubnetID
    AzFWPolicy_Name: 'dstAzFW_Policy'
    azfwSubnetID: destinationVNET.outputs.azfwSubnetID
    location: dstLocation
  }
}

// Azure Bastion for connecting to the Virtual Machines
module sourceBastion './Modules/Bastion.bicep' = {
  name: 'srcBastion'
  params: {
    bastionSubnetID: sourceVNET.outputs.bastionSubnetID
    location: srcLocation
  }
}

