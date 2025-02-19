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

module virtualNetwork_Hub '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet-hub'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    virtualNetwork_Name: 'vnet-hub'
  }
}

module virtualMachine_Client '../../../modules/Microsoft.Compute/VirtualMachine/Windows/Server2025_General.bicep' = {
  name: 'vm-client'
  params: {
    location: location
    acceleratedNetworking: acceleratedNetworking
    subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'vm-client'
    vmSize: virtualMachine_Size
  }
}

module bastion '../../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    location: location
    bastion_SubnetID: virtualNetwork_Hub.outputs.bastion_SubnetID
    bastion_name: 'bastion'
  }
}
