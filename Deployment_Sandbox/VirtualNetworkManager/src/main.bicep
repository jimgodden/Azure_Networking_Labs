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
param acceleratedNetworking bool = false

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

module virtualNetwork_Hub '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'virtualNetwork_Hub'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.100.0.0/16'
    virtualNetwork_Name: 'virtualNetwork_Hub'
  }
}

module virtualNetwork_Spoke1 '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'virtualNetwork_Spoke1'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.101.0.0/16'
    virtualNetwork_Name: 'virtualNetwork_Spoke1'
  }
}

module virtualNetworkManager '../../../modules/Microsoft.Network/VirtualNetworkManager.bicep' = {
  name: 'virtualNetworkManager'
  params: {
    location: location
    networkGroupMembershipType: 'static'
    VirtualNetwork_Hub_Id: virtualNetwork_Hub.outputs.virtualNetwork_ID
    VirtualNetwork_Spoke_Ids: [virtualNetwork_Spoke1.outputs.virtualNetwork_ID]
  }
}

module virtualMachine_Windows_Hub '../../../modules/Microsoft.Compute/VirtualMachine/Windows/Server20XX_Default.bicep' = {
  name: 'winVM-hub'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'winVM-hub'
    vmSize: virtualMachine_Size
    windowsServerVersion: '2022-datacenter-g2'
    scriptFileUri: '${virtualMachine_ScriptFileLocation}WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}

module virtualMachine_Windows_Spoke1 '../../../modules/Microsoft.Compute/VirtualMachine/Windows/Server20XX_Default.bicep' = {
  name: 'winVM-Spoke1'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork_Spoke1.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'winVM-Spoke1'
    vmSize: virtualMachine_Size
    windowsServerVersion: '2022-datacenter-g2'
    scriptFileUri: '${virtualMachine_ScriptFileLocation}WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}

module bastion '../../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_name: 'hub_bastion'
    bastion_SubnetID: virtualNetwork_Hub.outputs.bastion_SubnetID
    location: location
  }
}
