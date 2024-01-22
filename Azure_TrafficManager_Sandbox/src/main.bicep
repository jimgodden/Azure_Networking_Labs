@description('Azure Datacenter location for the source resources')
param locationA string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param virtualMachine_Size string = 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = false

module virtualNetworkA '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet'
  params: {
    location: locationA
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    virtualNetwork_Name: 'vnet'
  }
}

module virtualMachine_Windows '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'WebServVM-A'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationA
    subnet_ID: virtualNetworkA.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'WebServVM-A'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_WebServer.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_WebServer.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}

module bastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_SubnetID: virtualNetworkA.outputs.bastion_SubnetID
    location: locationA
  }
}


