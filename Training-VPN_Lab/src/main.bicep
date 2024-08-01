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

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

// Virtual Networks
module virtualNetworkA '../../Modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnetA'
  params: {
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    location: location
    virtualNetwork_Name: 'vnetA'
  }
}

// module virtualNetworkB '../../Modules/Microsoft.Network/VirtualNetwork.bicep' = {
//   name: 'vnetB'
//   params: {
//     virtualNetwork_AddressPrefix: '10.2.0.0/16'
//     location: location
//     virtualNetwork_Name: 'vnetB'
//   }
// }

// module virtualNetworkC '../../Modules/Microsoft.Network/VirtualNetwork.bicep' = {
//   name: 'vnetC'
//   params: {
//     virtualNetwork_AddressPrefix: '10.3.0.0/16'
//     location: location
//     virtualNetwork_Name: 'vnetC'
//   }
// }

module virtualNetworkGatewayA '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'virtualNetworkGatewayA'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65530
    virtualNetworkGateway_Name: 'virtualNetworkGatewayA'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetworkA.outputs.gateway_SubnetID
    virtualNetworkGateway_SKU: virtualNetworkGateway_SKU
    activeActive: virtualNetworkGateway_ActiveActive
  }
}

// module virtualNetworkGatewayB '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
//   name: 'virtualNetworkGatewayB'
//   params: {
//     location: location
//     virtualNetworkGateway_ASN: 65531
//     virtualNetworkGateway_Name: 'virtualNetworkGatewayB'
//     virtualNetworkGateway_Subnet_ResourceID: virtualNetworkB.outputs.gateway_SubnetID
//     virtualNetworkGateway_SKU: virtualNetworkGateway_SKU
//     activeActive: virtualNetworkGateway_ActiveActive
//   }
// }

// module virtualNetworkGatewayC '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
//   name: 'virtualNetworkGatewayC'
//   params: {
//     location: location
//     virtualNetworkGateway_ASN: 65532
//     virtualNetworkGateway_Name: 'virtualNetworkGatewayC'
//     virtualNetworkGateway_Subnet_ResourceID: virtualNetworkC.outputs.gateway_SubnetID
//     virtualNetworkGateway_SKU: virtualNetworkGateway_SKU
//     activeActive: virtualNetworkGateway_ActiveActive
//   }
// }

module virtualMachine_WindowsA '../../Modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'VMWindowsA'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetworkA.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'VM-A'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_DNS.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_DNS.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}

// module virtualMachine_WindowsB '../../Modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
//   name: 'VMWindowsB'
//   params: {
//     acceleratedNetworking: acceleratedNetworking
//     location: location
//     subnet_ID: virtualNetworkB.outputs.general_SubnetID
//     virtualMachine_AdminPassword: virtualMachine_AdminPassword
//     virtualMachine_AdminUsername: virtualMachine_AdminUsername
//     virtualMachine_Name: 'VM-B'
//     virtualMachine_Size: virtualMachine_Size
//     virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
//     virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_DNS.ps1'
//     commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_DNS.ps1 -Username ${virtualMachine_AdminUsername}'
//   }
// }

// module virtualMachine_WindowsC '../../Modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
//   name: 'VMWindowsC'
//   params: {
//     acceleratedNetworking: acceleratedNetworking
//     location: location
//     subnet_ID: virtualNetworkC.outputs.general_SubnetID
//     virtualMachine_AdminPassword: virtualMachine_AdminPassword
//     virtualMachine_AdminUsername: virtualMachine_AdminUsername
//     virtualMachine_Name: 'VM-C'
//     virtualMachine_Size: virtualMachine_Size
//     virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
//     virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_DNS.ps1'
//     commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_DNS.ps1 -Username ${virtualMachine_AdminUsername}'
//   }
// }

module bastionA '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'BastionA'
  params: {
    bastion_name: 'BastionA'
    bastion_SubnetID: virtualNetworkA.outputs.bastion_SubnetID
    location: location
    bastion_SKU: 'Standard'
  }
}

// module bastionB '../../modules/Microsoft.Network/Bastion.bicep' = {
//   name: 'BastionB'
//   params: {
//     bastion_name: 'BastionB'
//     bastion_SubnetID: virtualNetworkB.outputs.bastion_SubnetID
//     location: location
//     bastion_SKU: 'Standard'
//   }
// }

// module bastionC '../../modules/Microsoft.Network/Bastion.bicep' = {
//   name: 'BastionC'
//   params: {
//     bastion_name: 'BastionC'
//     bastion_SubnetID: virtualNetworkC.outputs.bastion_SubnetID
//     location: location
//     bastion_SKU: 'Standard'
//   }
// }
