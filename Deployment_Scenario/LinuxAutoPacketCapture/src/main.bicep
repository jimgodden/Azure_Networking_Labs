@description('Azure Datacenter location for the source resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachineScaleSet_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachineScaleSet_AdminPassword string

@description('Size of the Virtual Machines')
param virtualMachineScaleSet_Size string = 'Standard_D2as_v4' // 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = true

var virtualMachineScaleSet_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

module virtualNetwork '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    virtualNetwork_Name: 'vnet'
  }
}

module vmss_Linux '../../../modules/Microsoft.Compute/VirtualMachineScaleSets/Ubuntu22.bicep' = {
  name: 'linuxVMSS'
  params: {
    virtualMachineScaleSet_Name: 'LinuxVMSS'
    capacity: 1
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork.outputs.general_SubnetID
    virtualMachineScaleSet_AdminPassword: virtualMachineScaleSet_AdminPassword
    virtualMachineScaleSet_AdminUsername: virtualMachineScaleSet_AdminUsername
    virtualMachineScaleSet_Size: virtualMachineScaleSet_Size
    virtualMachineScaleSet_ScriptFileLocation: virtualMachineScaleSet_ScriptFileLocation
    virtualMachineScaleSet_ScriptFileName: 'tcpdumpScript.sh'
    commandToExecute: './tcpdumpScript.sh'
  }
}

module bastion '../../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_name: 'Hub_Bastion'
    bastion_SubnetID: virtualNetwork.outputs.bastion_SubnetID
    location: location
  }
}
