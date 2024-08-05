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

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

@description('''
Storage account name restrictions:
- Storage account names must be between 3 and 24 characters in length and may contain numbers and lowercase letters only.
- Your storage account name must be unique within Azure. No two storage accounts can have the same name.
''')
@minLength(3)
@maxLength(24)
param storageAccount_Name string = 'stortemp${uniqueString(resourceGroup().id)}'

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

module virtualNetwork_src '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet-src'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    virtualNetwork_Name: 'vnet-src'
  }
}

module virtualNetwork_dst '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet-dst'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    virtualNetwork_Name: 'vnet-dst'
  }
}

module vng_Src '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'vng_src'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65530
    virtualNetworkGateway_Name: 'Vng_Src'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork_src.outputs.gateway_SubnetID
  }
}

module vng_Src_to_vng_Dst_connection '../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'vng-src-to-vng-dst-connection'
  params: {
    location: location
    virtualNetworkGateway_ID: vng_Src.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_Name: vng_Dst.outputs.virtualNetworkGateway_Name
    vpn_Destination_BGPIPAddress: vng_Dst.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_ASN: vng_Dst.outputs.virtualNetworkGateway_ASN
    vpn_Destination_PublicIPAddress: vng_Dst.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
  }
}

module vng_dst_to_vng_src_connection '../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'b-to-a-connection'
  params: {
    location: location
    virtualNetworkGateway_ID: vng_Dst.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_Name: vng_Src.outputs.virtualNetworkGateway_Name
    vpn_Destination_PublicIPAddress: vng_Src.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_Destination_BGPIPAddress: vng_Src.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_ASN: vng_Src.outputs.virtualNetworkGateway_ASN
    vpn_SharedKey: vpn_SharedKey
  }
}

module vng_Dst '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'vng_Dst'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65531
    virtualNetworkGateway_Name: 'virtualNetworkGatewayB'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork_dst.outputs.gateway_SubnetID
  }
}

module virtualMachine_Windows_Src '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
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
    virtualMachine_ScriptFileName: 'WinServ2022_PsPing.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_PsPing.ps1 -DestinationIP "10.1.0.4" -DestinationPort 3389'
  }
}

module virtualMachine_Windows_Dst '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
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



module bastion_src '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion_src'
  params: {
    bastion_name: 'src_bastion'
    bastion_SubnetID: virtualNetwork_src.outputs.bastion_SubnetID
    location: location
  }
}
