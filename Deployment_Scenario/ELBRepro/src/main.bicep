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

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

module virtualNetworkClient '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnetClient'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    virtualNetwork_Name: 'vnetClient'
  }
}

module ClientVMs '../../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = [ for i in range(1, 2):  {
  name: 'ClientVM${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetworkClient.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'ClientVM${i}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_DNS.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_DNS.ps1 -Username ${virtualMachine_AdminUsername}'
  }
} ]

module publicLoadBalancer '../../../modules/Microsoft.Network/PublicLoadBalancer.bicep' = {
  name: 'elb'
  params: {
    location: location
    publicLoadBalancer_Name: 'elb'
    enableTcpReset: true
  }
}

module populateBackendAddressPools '../../../modules/Microsoft.Network/NetworkInterface_Attach_BackendPool.bicep' = [ for i in range(1, 2): {
  name: 'populateBackendAddressPools${i}'
  params: {
    backendAddressPool_Id: publicLoadBalancer.outputs.publicLoadBalancer_BackendAddressPoolID
    location: location
    networkInterface_Name: [ClientVMs[i - 1].outputs.networkInterface_Name]
    networkInterface_SubnetID: [virtualNetworkClient.outputs.general_SubnetID]
    networkInterface_IPConfig_Name: [ClientVMs[i - 1].outputs.networkInterface_IPConfig0_Name]
  }
  dependsOn: [
    #disable-next-line no-unnecessary-dependson
    publicLoadBalancer
  ]
} ]

module bastionVNET '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnetBastion'
  params: {
    virtualNetwork_Name: 'vnetBastion'
    location: location
    virtualNetwork_AddressPrefix: '10.200.0.0/16'
  }
}

module bastion_to_client '../../../modules/Microsoft.Network/VirtualNetworkPeeringSpoke2Spoke.bicep' = {
  name: 'bastion_to_client'
  params: {
    virtualNetwork1_Name: virtualNetworkClient.outputs.virtualNetwork_Name
    virtualNetwork2_Name: bastionVNET.outputs.virtualNetwork_Name
  }
}

module bastion_to_server '../../../modules/Microsoft.Network/VirtualNetworkPeeringSpoke2Spoke.bicep' = {
  name: 'bastion_to_server'
  params: {
    virtualNetwork1_Name: virtualNetworkServer.outputs.virtualNetwork_Name
    virtualNetwork2_Name: bastionVNET.outputs.virtualNetwork_Name
  }
}

module bastion '../../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_name: 'hub_bastion'
    bastion_SubnetID: bastionVNET.outputs.bastion_SubnetID
    location: location
  }
}


module virtualNetworkServer '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnetServer'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    virtualNetwork_Name: 'vnetServer'
  }
}

module ServerVM '../../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'ServerVM'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetworkServer.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'ServerVM'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_WebServer.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_WebServer.ps1 -Username ${virtualMachine_AdminUsername}'
    addPublicIPAddress: true
  }
}
