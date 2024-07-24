@description('Azure Datacenter location for the source resources')
param location string = resourceGroup().location

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

@description('Set to true if you want to deploy the Virtual Network Gateway in an Active-Active configuration.')
param virtualNetworkGateway_ActiveActive bool = false

@description('Sku name of the Azure Firewall.  Allowed values are Basic, Standard, and Premium')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param azureFirewall_SKU string = 'Basic'

@description('If true, an Azure Firewall will be deployed in both source and destination')
param isUsingAzureFirewall bool = false

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

// Virtual Networks
module virtualNetwork '../../Modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: location
    virtualNetwork_Name: 'vnet'
  }
}

module virtualNetworkGateway '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'virtualNetworkGateway'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65530
    virtualNetworkGateway_Name: 'virtualNetworkGateway'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork.outputs.gateway_SubnetID
    virtualNetworkGateway_SKU: virtualNetworkGateway_SKU
    activeActive: virtualNetworkGateway_ActiveActive
  }
}

module virtualMachine_Windows '../../Modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'VMWindows'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'VM-Windows'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_DNS.ps1 -Username ${virtualMachine_AdminUsername}'
    privateIPAddress: cidrHost( virtualNetwork.outputs.general_Subnet_AddressPrefix, 3 )
    privateIPAllocationMethod: 'Static'
  }
}

module virtualMachine_Linx '../../Modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = {
  name: 'VMLinux'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'VM-Linux'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'Ubuntu20_DNS_Config.sh'
    commandToExecute: './Ubuntu20_DNS_Config.sh'
    privateIPAddress: cidrHost( virtualNetwork.outputs.general_Subnet_AddressPrefix, 4 )
    privateIPAllocationMethod: 'Static'
  }
}

module azureFirewall '../../modules/Microsoft.Network/AzureFirewall.bicep' = if (isUsingAzureFirewall) {
  name: 'azureFirewall'
  params: {
    azureFirewall_Name: 'azureFirewall'
    azureFirewall_SKU: azureFirewall_SKU
    azureFirewall_ManagementSubnet_ID: virtualNetwork.outputs.azureFirewallManagement_SubnetID
    azureFirewallPolicy_Name: 'azureFirewall_Policy'
    azureFirewall_Subnet_ID: virtualNetwork.outputs.azureFirewall_SubnetID
    location: location
  }
  dependsOn: [
    virtualNetworkGateway
  ]
}

module bastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'Bastion'
  params: {
    bastion_name: 'Bastion'
    bastion_SubnetID: virtualNetwork.outputs.bastion_SubnetID
    location: location
    bastion_SKU: 'Standard'
  }
}
