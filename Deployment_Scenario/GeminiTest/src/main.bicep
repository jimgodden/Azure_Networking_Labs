@description('Azure Datacenter location for the source resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = true

@maxValue(99)
@description('Number of Windows Virtual Machines to deploy in the source side.  This number is irrelevant if not deploying Windows Virtual Machines')
param numberOfDNSServers int = 4

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

// Virtual Networks
module virtualNetwork_Source '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'srcVNET'
  params: {
    networkSecurityGroup_Default_Name: 'srcNSG'
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: location
    virtualNetwork_Name: 'srcVNET'
    dnsServers: [ for i in range(1, numberOfDNSServers): {
      dnsServer_IPAddress: dnsServers[i - 1].outputs.networkInterface_PrivateIPAddress
    }]
  }
  dependsOn: [
    dnsServers
  ]
}

module virtualNetwork_Destination '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'dstVNET'
  params: {
    networkSecurityGroup_Default_Name: 'dstNSG'
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    location: location
    virtualNetwork_Name: 'dstVNET'
  }
}

module virtualNetworkPeering_Source_to_Destination '../../../modules/Microsoft.Network/VirtualNetworkPeering.bicep' = {
  name: 'Source_to_Destination_Peering'
  params: {
    virtualNetwork_Destination_Name: virtualNetwork_Source.outputs.virtualNetwork_Name
    virtualNetwork_Source_Name: virtualNetwork_Destination.outputs.virtualNetwork_Name
  }
  // dependsOn: [
  //   sourceBastion
  // ]
}


module clientVMSS '../../../modules/Microsoft.Compute/VirtualMachineScaleSets/WinServ2025.bicep' = {
  name: 'dstVMSS'
  params: {
    location: location
    acceleratedNetworking: acceleratedNetworking
    subnet_ID: virtualNetwork_Source.outputs.general_SubnetID
    virtualMachineScaleSet_AdminPassword: virtualMachine_AdminPassword
    virtualMachineScaleSet_AdminUsername: virtualMachine_AdminUsername
    virtualMachineScaleSet_Name: 'clientVM-'
    virtualMachineScaleSet_Size: 'Standard_D2as_v5' // 'Standard_D2as_v5' // 'Standard_D48as_v5'
    capacity: 4
    virtualMachineScaleSet_ScriptFileName: 'VMSSClientest.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File '
  }
}

module dnsServers '../../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = [ for i in range(1, numberOfDNSServers): {
  name: 'srcVMWindows${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork_Destination.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'dns${i}'
    virtualMachine_Size: 'Standard_D2ls_v5'
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_DNS.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_DNS.ps1 -Username ${virtualMachine_AdminUsername}'
  }
} ]

module linuxLoggingServer '../../../modules/Microsoft.Compute/VirtualMachine/Linux/Ubuntu24_LoggingWebsite.bicep' = {
  name: 'loggingServer'
  params: {
    location: location
    acceleratedNetworking: acceleratedNetworking
    subnet_ID: virtualNetwork_Destination.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'loggingServer'
    virtualMachine_Size: 'Standard_D2ls_v5'
  }
}

module bastion '../../../modules/Microsoft.Network/BastionEverything.bicep' = {
  name: 'bastion'
  params: {
    location: location
    bastion_name: 'bastion'
    bastion_SubnetID: virtualNetwork_Destination.outputs.bastion_SubnetID
    virtualNetwork_AddressPrefix: '10.100.0.0/24'
    bastion_SKU: 'Standard'
    other_VirtualNetwork_Ids: [
      virtualNetwork_Source.outputs.virtualNetwork_ID
      virtualNetwork_Destination.outputs.virtualNetwork_ID
    ]
  }
}
