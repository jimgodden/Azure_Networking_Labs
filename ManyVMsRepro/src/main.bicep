@description('Azure Datacenter location for the resources')
param location string = 'eastus'

@description('Resource ID of the subnet within a Virtual Network')
param subnet_ID string = '/subscriptions/a2c8e9b2-b8d3-4f38-8a72-642d0012c518/resourceGroups/manyvmsinfra_6/providers/Microsoft.Network/virtualNetworks/VNet/subnets/General'

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
param startingNumberOfVirtualMachines int = 4

@maxValue(1000)
@description('Number of Virtual Machines to be used as the source of the traffic')
param endingNumberOfVirtualMachines int = 5

@description('SAS URI of a blob from a Storage Account with Upload permissions.')
param blobSASURI string = 'https://stortempduz4ohpmmi3r2.blob.core.windows.net/results?sp=w&st=2024-05-30T03:41:54Z&se=2024-05-30T11:41:54Z&spr=https&sv=2022-11-02&sr=c&sig=dEYAEuDvd2yySPodd2rh8NDNNmORR%2B4%2FjO2sGka8bug%3D'

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'


module SourceVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep'  = [ for i in range(startingNumberOfVirtualMachines, endingNumberOfVirtualMachines): {
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
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File ManyVMsRepro.ps1 -SASURI "${blobSASURI}" -PrivateEndpointIP "10.1.0.5"'
  }
} ]

