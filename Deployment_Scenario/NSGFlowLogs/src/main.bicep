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

module virtualNetwork_src '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet-src'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    virtualNetwork_Name: 'vnet-src'
  }
}

module virtualNetwork_dst '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet-dst'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    virtualNetwork_Name: 'vnet-dst'
  }
}

module src_to_dst_vnetPeering '../../../modules/Microsoft.Network/VirtualNetworkPeeringSpoke2Spoke.bicep' = {
  name: 'vnetpeering'
  params: {
    virtualNetwork1_Name: virtualNetwork_src.outputs.virtualNetwork_Name
    virtualNetwork2_Name: virtualNetwork_dst.outputs.virtualNetwork_Name
  }
}

module virtualMachine_Windows_SRC '../../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'winVM-src'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork_src.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'winVM-src'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_LongRunningConnections_Client.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_LongRunningConnections_Client.ps1 -DestinationIP "10.1.0.4" -DestinationPort 5500'
  }
}

module virtualMachine_Windows_dst '../../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'winVM-dst'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork_dst.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'winVM-dst'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_LongRunningConnections_Server.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_LongRunningConnections_Server.ps1 -LocalPort 5500'
  }
}

module storageAccount '../../../modules/Microsoft.Storage/StorageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    location: location
    storageAccount_Name: storageAccount_Name
  }
}

module workspace '../../../modules/Microsoft.OperationalInsights/Workspaces.bicep' = {
  name: 'workspace'
  params: {
    location: location
    Workspaces_name: 'testworkspace'
  }
}

module nsgFlowLogs_src '../../../modules/Microsoft.Network/FlowLogs.bicep' = {
  name: 'nsgFLowLogs_src'
  scope: resourceGroup('NetworkWatcherRG')
  params: {
    FlowLogs_TargetResourceId: virtualNetwork_src.outputs.networkSecurityGroup_ID
    location: location
    StorageAccount_Id: storageAccount.outputs.storageAccount_ID
    workspaceResourceId: workspace.outputs.LogAnalyticsWorkspace_ID
    FlowLogs_Version: 2
  }
}

resource networkSecurityGroup_Expected 'Microsoft.Network/networkSecurityGroups/securityRules@2022-11-01' = {
  name: 'vnet-src_NSG_General/Expected'
  properties: {
    description: 'Expected'
    protocol: '*'
    sourcePortRange: '*'
    destinationPortRange: '*'
    sourceAddressPrefix: '10.0.0.4'
    destinationAddressPrefix: '10.1.0.4'
    access: 'Allow'
    priority: 200
    direction: 'Outbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
  }
  dependsOn: [
    virtualNetwork_src
  ]
}

resource networkSecurityGroup_Error 'Microsoft.Network/networkSecurityGroups/securityRules@2022-11-01' = {
  name: 'vnet-src_NSG_General/Error'
  properties: {
    description: 'Error'
    protocol: '*'
    sourcePortRange: '*'
    destinationPortRange: '*'
    sourceAddressPrefix: '10.0.0.0/24'
    destinationAddressPrefix: '10.1.0.0/24'
    access: 'Allow'
    priority: 201
    direction: 'Outbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
  }
  dependsOn: [
    virtualNetwork_src
  ]
}

module bastion '../../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_name: 'hub_bastion'
    bastion_SubnetID: virtualNetwork_src.outputs.bastion_SubnetID
    location: location
  }
}

output vmResourceId string = virtualMachine_Windows_SRC.outputs.virtualMachine_Id
