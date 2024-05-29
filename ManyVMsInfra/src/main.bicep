@description('Azure Datacenter location for the resources')
param location string = 'eastus'

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
param numberOfVMs int = 10

@description('''
Storage account name restrictions:
- Storage account names must be between 3 and 24 characters in length and may contain numbers and lowercase letters only.
- Your storage account name must be unique within Azure. No two storage accounts can have the same name.
''')
@minLength(3)
@maxLength(24)
param storageAccount_Name string = 'stortemp${uniqueString(resourceGroup().id)}'

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'


module virtualNetwork '../../modules/Microsoft.Network/VirtualNetworkBigSubnets.bicep' = {
  name: 'VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/8'
    location: location
    virtualNetwork_Name: 'VNet'
  }
}

module SourceVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep'  = [ for i in range(1, numberOfVMs): {
  name: 'SourceVM-${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'SourceVM-${i}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'ManyVMsRepro_1_of_3.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File ManyVMsRepro_1_of_3.ps1 -StorageAccountName ${storageAccount.outputs.storageAccount_Name} -StorageAccountKey ${storageAccount.outputs.storageAccount_key0} -ContainerName ${storageAccountContainers.outputs.container_Names[0]} -PrivateEndpointIP 10.1.0.5'
  }
} ]

module Bastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'Bastion'
  params: {
    bastion_name: 'Bastion'
    bastion_SubnetID: virtualNetwork.outputs.bastion_SubnetID
    location: location
  }
}

module storageAccount '../../modules/Microsoft.Storage/StorageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    location: location
    storageAccount_Name: storageAccount_Name
  }
}

module storageAccountContainers '../../modules/Microsoft.Storage/Container.bicep' = {
  name: 'storageAccountContainers'
  params: {
    container_Names: ['unfilteredcaptures', 'needsreview', 'ignore']
    storageAccount_BlobServices_Name: storageAccount.outputs.storageAccount_BlobServices_Name
    storageAccount_Name: storageAccount.outputs.storageAccount_Name
  }
}

module StorageAccount_Blob_PrivateEndpoint '../../modules/Microsoft.Network/PrivateEndpoint.bicep' = {
  name: 'StorageAccount_Blob_PrivateEndpoint'
  params: {
    groupID: 'blob'
    location: location
    privateDNSZone_Name: 'privatelink.blob.${environment().suffixes.storage}'
    privateEndpoint_Name: '${storageAccount_Name}_blob_pe'
    privateEndpoint_SubnetID: virtualNetwork.outputs.privateEndpoint_SubnetID
    privateLinkServiceId: storageAccount.outputs.storageAccount_ID
    virtualNetwork_IDs: [
      virtualNetwork.outputs.virtualNetwork_ID
    ]  
  }
}

module PrivateEndpointNetworkInterface '../../modules/Microsoft.Network/PrivateEndpointNetworkInterface.bicep' = {
  name: 'PE_NIC'
  params: {
    existing_PrivateEndpoint_NetworkInterface_Name: StorageAccount_Blob_PrivateEndpoint.outputs.privateEndpoint_NetworkInterface_Name
  }
}
