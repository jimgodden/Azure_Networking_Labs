@description('Azure Datacenter location for the resources')
param location string = 'eastus'

@description('Resource ID of the subnet within a Virtual Network')
param subnet_ID string = ''

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param virtualMachine_Size string = 'Standard_E4d_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = true

@maxValue(1000)
@description('Number of Virtual Machines to be used as the source of the traffic')
param startingNumberOfVirtualMachines int = 0

@maxValue(1000)
@description('Number of Virtual Machines to be used as the source of the traffic')
param numberOfVirtualMachinesToBeCreated int = 50

param storageAccountName string = ''
param storageAccountKey0 string = ''
param storageAccountContainerName string = ''
param privateEndpointIP string = ''

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'


module SourceVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep'  = [ for i in range(startingNumberOfVirtualMachines, numberOfVirtualMachinesToBeCreated): {
  name: 'SourceVM-${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: subnet_ID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'VM-${i}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'ManyVMsRepro.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File ManyVMsRepro.ps1 -storageAccountName "${storageAccountName}" -storageAccountKey0 "${storageAccountKey0}" -storageAccountContainerName "${storageAccountContainerName}" -PrivateEndpointIP "${privateEndpointIP}"'
  }
} ]
