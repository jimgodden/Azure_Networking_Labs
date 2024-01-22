@description('Azure Datacenter location for the source resources')
param location string = resourceGroup().location

@description('Unique prefix for this Virtual Machine and Virtual Network.  Suggested is to use simple prefixes like A, B, or C etc.')
param uniqueNamePrefix string

@description('Address Prefix of the Virtual Network.  Example: 10.0.0.0/16')
param virtualNetwork_AddressPrefix string

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

module virtualNetwork '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet${uniqueNamePrefix}'
  params: {
    location: location
    virtualNetwork_AddressPrefix: virtualNetwork_AddressPrefix
    virtualNetwork_Name: 'vnet${uniqueNamePrefix}'
  }
}

module addNSGRules 'AddNSGRuleForAtmAnd443.bicep' = {
  name: 'addNSGRules${uniqueNamePrefix}'
  params: {
    networkSecurityGroup_Name: virtualNetwork.outputs.networkSecurityGroup_Name
  }
}

module virtualMachine_WebServ '../../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'WebServVM${uniqueNamePrefix}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'WebServVM${uniqueNamePrefix}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_WebServer.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_WebServer.ps1 -Username ${virtualMachine_AdminUsername} -Location ${location}'
    addPublicIPAddress: true
  }
}

module virtualMachine_Client '../../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'ClientVM${uniqueNamePrefix}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'ClientVM${uniqueNamePrefix}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}

output virtualNetwork_Name string = virtualNetwork.outputs.virtualNetwork_Name
