@description('Azure Datacenter location for the source resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param virtualMachine_Size string = 'Standard_D2s_v4' // 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = true

module virtualNetwork '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    virtualNetwork_Name: 'vnet'
  }
}

// module virtualMachine_Windows '../../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
//   name: 'winVM'
//   params: {
//     acceleratedNetworking: acceleratedNetworking
//     location: location
//     subnet_ID: virtualNetwork.outputs.general_SubnetID
//     virtualMachine_AdminPassword: virtualMachine_AdminPassword
//     virtualMachine_AdminUsername: virtualMachine_AdminUsername
//     virtualMachine_Name: 'winVM'
//     virtualMachine_Size: virtualMachine_Size
//     virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
//     virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_WebServer.ps1'
//     commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_WebServer.ps1 -Username ${virtualMachine_AdminUsername}'
//     addPublicIPAddress: true
//   }
// }

var vmConfigs = [
  // {
  //   name: 'winVM16'
  //   image: '2016-datacenter-gensecond'
  // }
  // {
  //   name: 'winVM19'
  //   image: '2019-datacenter-gensecond'
  // }
  // {
  //   name: 'winVM22'
  //   image: '2022-datacenter-g2'
  // }
  {
    name: 'winVM251'
    image: '2025-datacenter-azure-edition'
  }
]

module virtualMachine_Windows '../../../modules/Microsoft.Compute/VirtualMachine/Windows/Server20XX_General.bicep' = [for vm in vmConfigs: {
  name: vm.name
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: vm.name
    vmSize: virtualMachine_Size
    windowsServerVersion: vm.image
    installTools: true
    // addPublicIPAddress: true
  }
}]

module bastion '../../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_name: 'bastion'
    bastion_SubnetID: virtualNetwork.outputs.bastion_SubnetID
    location: location
    bastion_SKU: 'Basic'
  }
}
