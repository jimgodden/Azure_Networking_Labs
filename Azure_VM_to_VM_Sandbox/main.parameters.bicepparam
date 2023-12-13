using './src/main.bicep' /*Provide a path to a bicep template*/

// @description('Azure Datacenter location for the source resources')
// param srcLocation =

// @description('Azure Datacenter location for the destination resources')
// param dstLocation =

param virtualMachine_AdminUsername = 'jamesgodden'

param virtualMachine_AdminPassword = getSecret('a2c8e9b2-b8d3-4f38-8a72-642d0012c518', 'Main', 'Main-jamesg-kv', 'genericPassword')

param vpn_SharedKey = getSecret('a2c8e9b2-b8d3-4f38-8a72-642d0012c518', 'Main', 'Main-jamesg-kv', 'genericVPNSharedKey')

@description('Size of the Virtual Machines')
param virtualMachine_Size = 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking = false

@description('SKU of the Virtual Network Gateway')
param virtualNetworkGateway_SKU = 'Basic'

@description('Sku name of the Azure Firewall.  Allowed values are Basic, Standard, and Premium')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param azureFirewall_SKU = 'Basic'

@description('If true, Virtual Networks will be connected via Virtual Network Gateway S2S connection.  If false, Virtual Network Peering will be used instead.')
param isUsingVPN = true

@description('If true, an Azure Firewall will be deployed in both source and destination')
param isUsingAzureFirewall = true

@description('If true, a Windows VM will be deployed in both source and destination')
param isUsingWindows = true

@maxValue(99)
@description('Number of Windows Virtual Machines to deploy in the source side.  This number is irrelevant if not deploying Windows Virtual Machines')
param numberOfSourceSideWindowsVMs = 1

@maxValue(99)
@description('Number of Windows Virtual Machines to deploy in the destination side.  This number is irrelevant if not deploying Windows Virtual Machines')
param numberOfDestinationSideWindowsVMs = 1

@description('If true, a Linux VM will be deployed in both source and destination')
param isUsingLinux = true

@maxValue(99)
@description('Number of Linux Virtual Machines to deploy in the source side.  This number is irrelevant if not deploying Linux Virtual Machines')
param numberOfSourceSideLinuxVMs  = 1

@maxValue(99)
@description('Number of Linux Virtual Machines to deploy in the destination side.  This number is irrelevant if not deploying Linux Virtual Machines')
param numberOfDestinationSideLinuxVMs  = 1















