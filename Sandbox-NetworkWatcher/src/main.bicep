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

@description('''
Storage account name restrictions:
- Storage account names must be between 3 and 24 characters in length and may contain numbers and lowercase letters only.
- Your storage account name must be unique within Azure. No two storage accounts can have the same name.
''')
@minLength(3)
@maxLength(24)
param storageAccount_Name string = 'stortemp${uniqueString(resourceGroup().id)}'

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

module virtualNetwork '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    virtualNetwork_Name: 'vnet'
  }
}

module networkWatcher '../../modules/Microsoft.Network/NetworkWatcher.bicep' = {
  name: 'networkWatcher'
  scope: resourceGroup('NetworkWatcherRG')
  params: {
    FlowLogs_TargetResourceId: virtualNetwork.outputs.virtualNetwork_ID
    location: location
    srcEndpointVmResource_Id: virtualMachine_Windows.outputs.virtualMachine_Id
    StorageAccount_Id: storageAccount.outputs.storageAccount_ID
    workspaceResourceId: workspace.outputs.LogAnalyticsWorkspace_ID
  }
}

module virtualMachine_Windows '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'winVM'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'winVM'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}

module storageAccount '../../modules/Microsoft.Storage/StorageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    location: location
    storageAccount_Name: storageAccount_Name
  }
}

module workspace '../../modules/Microsoft.OperationalInsights/Workspaces.bicep' = {
  name: 'workspace'
  params: {
    location: location
    Workspaces_name: 'testworkspace'
  }
}

module bastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_name: 'hub_bastion'
    bastion_SubnetID: virtualNetwork.outputs.bastion_SubnetID
    location: location
  }
}

output vmResourceId string = virtualMachine_Windows.outputs.virtualMachine_Id
