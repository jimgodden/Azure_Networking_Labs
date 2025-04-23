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

@description('SKU of the Virtual Network Gateway')
param virtualNetworkGateway_SKU string = 'VpnGw1'

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

///var virtualMachine_ScriptFile = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2022_ConfigScript_DNS.ps1'

var virtualMachine_ScriptFile = 'https://supportability.visualstudio.com/AzureNetworking/_git/AzureNetworking?path=/.LabBoxRepo/Hybrid/VPN_P2S_TransitiveRouting-Training/WinServ2022_ConfigScript_DNS.ps1'


// Virtual Networks
module virtualNetworkA '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnetA'
  params: {
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    location: location
    virtualNetwork_Name: 'vnetA'
  }
}

module virtualNetworkB '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnetB'
  params: {
    virtualNetwork_AddressPrefix: '10.2.0.0/16'
    location: location
    virtualNetwork_Name: 'vnetB'
  }
}

module virtualNetworkC '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnetC'
  params: {
    virtualNetwork_AddressPrefix: '10.3.0.0/16'
    location: location
    virtualNetwork_Name: 'vnetC'
  }
}

module virtualNetworkHub '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnetHub'
  params: {
    virtualNetwork_AddressPrefix: '10.100.0.0/16'
    location: location
    virtualNetwork_Name: 'vnetHub'
  }
}

module bastionForAllVNETs '../../../modules/Microsoft.Network/BastionEverything.bicep' = {
  name: 'bastionForAllVNETs'
  params: {
    location: location
    bastion_name: 'Bastion'
    peered_VirtualNetwork_Ids: [
      virtualNetworkA.outputs.virtualNetwork_ID
      virtualNetworkB.outputs.virtualNetwork_ID
      virtualNetworkC.outputs.virtualNetwork_ID
      virtualNetworkHub.outputs.virtualNetwork_ID
    ]
    virtualNetwork_AddressPrefix: '10.200.0.0/16'
  }
}

// module virtualNetworks_to_Bastion_Peerings '../../../modules/Microsoft.Network/BastionVirtualNetworkHubPeerings.bicep' = {
//   name: 'virtualNetworks_to_Bastion_Peerings'
//   params: {
//     bastion_VirtualNetwork_Id: virtualNetworkHub.outputs.virtualNetwork_ID
//     other_VirtualNetwork_Ids: [
//       virtualNetworkA.outputs.virtualNetwork_ID
//       virtualNetworkB.outputs.virtualNetwork_ID
//       virtualNetworkC.outputs.virtualNetwork_ID
//     ]
//   }
// }

// module bastion '../../../modules/Microsoft.Network/Bastion.bicep' = {
//   name: 'Bastion'
//   params: {
//     bastion_name: 'Bastion'
//     bastion_SubnetID: virtualNetworkHub.outputs.bastion_SubnetID
//     location: location
//     bastion_SKU: 'Standard'
//   }
// }

module virtualNetworkGatewayA '../../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'virtualNetworkGatewayA'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65530
    virtualNetworkGateway_Name: 'virtualNetworkGatewayA'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetworkA.outputs.gateway_SubnetID
    virtualNetworkGateway_SKU: virtualNetworkGateway_SKU
    activeActive: false
  }
}

module vngA_to_vngB_connection '../../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway_noBGP.bicep' = {
  name: 'a-to-b-connection'
  params: {
    location: location
    virtualNetworkGateway_ID: virtualNetworkGatewayA.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_LocalAddressPrefix: virtualNetworkB.outputs.virtualNetwork_AddressPrefix
    vpn_Destination_Name: virtualNetworkGatewayB.outputs.virtualNetworkGateway_Name
    vpn_Destination_PublicIPAddress: virtualNetworkGatewayB.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
  }
}

module vngB_to_vngA_connection '../../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway_noBGP.bicep' = {
  name: 'b-to-a-connection'
  params: {
    location: location
    virtualNetworkGateway_ID: virtualNetworkGatewayB.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_LocalAddressPrefix: virtualNetworkA.outputs.virtualNetwork_AddressPrefix
    vpn_Destination_Name: virtualNetworkGatewayA.outputs.virtualNetworkGateway_Name
    vpn_Destination_PublicIPAddress: virtualNetworkGatewayA.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
  }
}

module virtualNetworkGatewayB '../../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'virtualNetworkGatewayB'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65531
    virtualNetworkGateway_Name: 'virtualNetworkGatewayB'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetworkB.outputs.gateway_SubnetID
    virtualNetworkGateway_SKU: virtualNetworkGateway_SKU
    activeActive: false
  }
}

module vngC_to_vngB_connection '../../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway_noBGP.bicep' = {
  name: 'c-to-b-connection'
  params: {
    location: location
    virtualNetworkGateway_ID: virtualNetworkGatewayC.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_LocalAddressPrefix: virtualNetworkB.outputs.virtualNetwork_AddressPrefix
    vpn_Destination_Name: virtualNetworkGatewayB.outputs.virtualNetworkGateway_Name
    vpn_Destination_PublicIPAddress: virtualNetworkGatewayB.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
  }
}

module vngB_to_vngC_connection '../../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway_noBGP.bicep' = {
  name: 'b-to-c-connection'
  params: {
    location: location
    virtualNetworkGateway_ID: virtualNetworkGatewayB.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_LocalAddressPrefix: virtualNetworkC.outputs.virtualNetwork_AddressPrefix
    vpn_Destination_Name: virtualNetworkGatewayC.outputs.virtualNetworkGateway_Name
    vpn_Destination_PublicIPAddress: virtualNetworkGatewayC.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
  }
}

module virtualNetworkGatewayC '../../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'virtualNetworkGatewayC'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65532
    virtualNetworkGateway_Name: 'virtualNetworkGatewayC'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetworkC.outputs.gateway_SubnetID
    virtualNetworkGateway_SKU: virtualNetworkGateway_SKU
    activeActive: false
  }
}

module virtualMachine_WindowsA '../../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine_ForLabbox.bicep' = {
  name: 'VMWindowsA'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetworkA.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'VM-A'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFiles: [ virtualMachine_ScriptFile ]
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_DNS.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}











module virtualMachine_WindowsB '../../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine_ForLabbox.bicep' = {
  name: 'VMWindowsB'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetworkB.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'VM-B'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFiles: [ virtualMachine_ScriptFile ]
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_DNS.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}












module virtualMachine_WindowsC '../../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine_ForLabbox.bicep' = {
  name: 'VMWindowsC'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetworkC.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'VM-C'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFiles: [ virtualMachine_ScriptFile ]
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_DNS.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}
