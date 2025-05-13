@description('Azure Datacenter location for the source resources')
param SourceLocation string = resourceGroup().location

@description('Azure Datacenter location for the destination resources')
param DestinationLocation string = SourceLocation

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

@description('Sku name of the Azure Firewall.  Allowed values are Basic, Standard, and Premium')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param azureFirewall_SKU string = 'Basic'

@description('If true, Virtual Networks will be connected via Virtual Network Gateway S2S connection.  If false, Virtual Network Peering will be used instead.')
param isUsingVPN bool = true

@description('If true, an Azure Firewall will be deployed in both source and destination')
param isUsingAzureFirewall bool = true

@description('If true, a Windows VM will be deployed in both source and destination')
param isUsingWindows bool = true

@maxValue(99)
@description('Number of Windows Virtual Machines to deploy in the source side.  This number is irrelevant if not deploying Windows Virtual Machines')
param numberOfSourceSideWindowsVMs int = 1

@maxValue(99)
@description('Number of Windows Virtual Machines to deploy in the destination side.  This number is irrelevant if not deploying Windows Virtual Machines')
param numberOfDestinationSideWindowsVMs int = 1

@description('If true, a Linux VM will be deployed in both source and destination')
param isUsingLinux bool = true

@maxValue(99)
@description('Number of Linux Virtual Machines to deploy in the source side.  This number is irrelevant if not deploying Linux Virtual Machines')
param numberOfSourceSideLinuxVMs  int = 1

@maxValue(99)
@description('Number of Linux Virtual Machines to deploy in the destination side.  This number is irrelevant if not deploying Linux Virtual Machines')
param numberOfDestinationSideLinuxVMs  int = 1

@description('Leave this as false.  If set to true, it will deploy a VM that is not used in this lab.  It is only here to trick the ARM template into populating the list of VM Sizes available in the region.')
param LeaveThisAsFalse bool = false

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

// Virtual Networks
module virtualNetwork_Source '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'srcVNET'
  params: {
    networkSecurityGroup_Default_Name: 'srcNSG'
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: SourceLocation
    virtualNetwork_Name: 'srcVNET'
  }
}

module virtualNetwork_Destination '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'dstVNET'
  params: {
    networkSecurityGroup_Default_Name: 'dstNSG'
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    location: DestinationLocation
    virtualNetwork_Name: 'dstVNET'
  }
}

module sourceVirtualNetworkGateway '../../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = if (isUsingVPN) {
  name: 'srcVNG'
  params: {
    location: SourceLocation
    virtualNetworkGateway_ASN: 65530
    virtualNetworkGateway_Name: 'srcVNG'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork_Source.outputs.gateway_SubnetID
    virtualNetworkGateway_SKU: virtualNetworkGateway_SKU
  }
}

module destinationVirtualNetworkGateway '../../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = if (isUsingVPN) {
  name: 'dstVNG'
  params: {
    location: DestinationLocation
    virtualNetworkGateway_ASN: 65531
    virtualNetworkGateway_Name: 'dstVNG'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork_Destination.outputs.gateway_SubnetID
    virtualNetworkGateway_SKU: virtualNetworkGateway_SKU
  }
}

// Connections to the other Virtual Network Gateway
module sourceVNG_Conn '../../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = if (isUsingVPN) {
  name: 'srcVNG_conn'
  params: {
    vpn_Destination_BGPIPAddress: destinationVirtualNetworkGateway.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_ASN: destinationVirtualNetworkGateway.outputs.virtualNetworkGateway_ASN
    virtualNetworkGateway_ID: sourceVirtualNetworkGateway.outputs.virtualNetworkGateway_ResourceID
    location: SourceLocation
    vpn_Destination_Name: 'dst'
    vpn_SharedKey: vpn_SharedKey
    vpn_Destination_PublicIPAddress: destinationVirtualNetworkGateway.outputs.virtualNetworkGateway_PublicIPAddress
  }
}

module destinationVNG_Conn '../../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = if (isUsingVPN) {
  name: 'dstVNG_conn'
  params: {
    vpn_Destination_BGPIPAddress: sourceVirtualNetworkGateway.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_ASN: sourceVirtualNetworkGateway.outputs.virtualNetworkGateway_ASN
    virtualNetworkGateway_ID: destinationVirtualNetworkGateway.outputs.virtualNetworkGateway_ResourceID
    location: DestinationLocation
    vpn_Destination_Name: 'src'
    vpn_SharedKey: vpn_SharedKey
    vpn_Destination_PublicIPAddress: sourceVirtualNetworkGateway.outputs.virtualNetworkGateway_PublicIPAddress
  }
}

module virtualNetworkPeering_Source_to_Destination '../../../modules/Microsoft.Network/VirtualNetworkPeering.bicep' = if (!isUsingVPN) {
  name: 'Source_to_Destination_Peering'
  params: {
    virtualNetwork_Destination_Name: virtualNetwork_Source.outputs.virtualNetwork_Name
    virtualNetwork_Source_Name: virtualNetwork_Destination.outputs.virtualNetwork_Name
  }
  dependsOn: [
    bastion
  ]
}

module sourceVM_Windows '../../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = [ for i in range(1, numberOfSourceSideWindowsVMs):  if (isUsingWindows) {
  name: 'srcVMWindows${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: SourceLocation
    networkInterface_Name: 'srcVM-Windows_NIC${i}'
    subnet_ID: virtualNetwork_Source.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'srcVM-Windows${i}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
  }
} ]

module destinationVM_Windows '../../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = [ for i in range(1, numberOfDestinationSideWindowsVMs):  if (isUsingWindows) {
  name: 'dstVMWindows${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: DestinationLocation
    networkInterface_Name: 'dstVM-Windows_NIC${i}'
    subnet_ID: virtualNetwork_Destination.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'dstVM-Windows${i}'
    virtualMachine_Size:  virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_WebServer.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_WebServer.ps1 -Username ${virtualMachine_AdminUsername}'
  }
} ]

module sourceVM_Linx '../../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = [ for i in range(1, numberOfSourceSideLinuxVMs):  if (isUsingLinux) {
  name: 'srcVMLinux${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: SourceLocation
    networkInterface_Name: 'srcVM-Linux_NIC${i}'
    subnet_ID: virtualNetwork_Source.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'srcVM-Linux${i}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'Ubuntu20_DNS_Config.sh'
    commandToExecute: './Ubuntu20_DNS_Config.sh'
  }
} ]

module destinationVMLinx '../../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = [ for i in range(1, numberOfDestinationSideLinuxVMs):  if (isUsingLinux) {
  name: 'dstVMLinux${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: DestinationLocation
    networkInterface_Name: 'dstVM-Linux_NIC${i}'
    subnet_ID: virtualNetwork_Destination.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'dstVM-Linux${i}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'Ubuntu20_WebServer_Config.sh'
    commandToExecute: './Ubuntu20_WebServer_Config.sh'
  }
} ]

module sourceAzFW '../../../modules/Microsoft.Network/AzureFirewall.bicep' = if (isUsingAzureFirewall) {
  name: 'srcAzFW'
  params: {
    azureFirewall_Name: 'srcAzFW'
    azureFirewall_SKU: azureFirewall_SKU
    azureFirewall_ManagementSubnet_ID: virtualNetwork_Source.outputs.azureFirewallManagement_SubnetID
    azureFirewallPolicy_Name: 'srcAzFW_Policy'
    azureFirewall_Subnet_ID: virtualNetwork_Source.outputs.azureFirewall_SubnetID
    location: SourceLocation
  }
  // dependsOn: [
  //   sourceVirtualNetworkGateway
  // ]
}

module destinationAzFW '../../../modules/Microsoft.Network/AzureFirewall.bicep' = if (isUsingAzureFirewall) {
  name: 'dstAzFW'
  params: {
    azureFirewall_Name: 'dstAzFW'
    azureFirewall_SKU: azureFirewall_SKU
    azureFirewall_ManagementSubnet_ID: virtualNetwork_Destination.outputs.azureFirewallManagement_SubnetID
    azureFirewallPolicy_Name: 'dstAzFW_Policy'
    azureFirewall_Subnet_ID: virtualNetwork_Destination.outputs.azureFirewall_SubnetID
    location: DestinationLocation
  }
  dependsOn: [
    destinationVirtualNetworkGateway
  ]
}

module bastion  '../../../modules/Microsoft.Network/BastionEverything.bicep' = {
  name: 'bastion'
  params: {
    location: SourceLocation
    bastion_name: 'bastion'
    peered_VirtualNetwork_Ids: [
      virtualNetwork_Source.outputs.general_SubnetID
      virtualNetwork_Destination.outputs.general_SubnetID
    ]
    virtualNetwork_AddressPrefix: '10.200.0.0/16'
  }
}

// Start of onprem_clientVM
var virtualMachine_Onprem_Client_Name = 'onprem-clientVM'
resource virtualMachine_Onprem_Client 'Microsoft.Compute/virtualMachines@2024-07-01' = if (LeaveThisAsFalse) {
  name: virtualMachine_Onprem_Client_Name
  location: SourceLocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: virtualMachine_Size
    }
    additionalCapabilities: {
      hibernationEnabled: false
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2025-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        name: '${virtualMachine_Onprem_Client_Name}_OsDisk_1'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        deleteOption: 'Delete'
        diskSizeGB: 127
      }
      dataDisks: []
      diskControllerType: 'SCSI'
    }
    osProfile: {
      computerName: virtualMachine_Onprem_Client_Name
      adminUsername: virtualMachine_AdminUsername
      adminPassword: virtualMachine_AdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          automaticByPlatformSettings: {
            rebootSetting: 'IfRequired'
          }
          assessmentMode: 'ImageDefault'
          enableHotpatching: true
        }
      }
      secrets: []
      allowExtensionOperations: true
    }
    securityProfile: {
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
      securityType: 'TrustedLaunch'
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: virtualMachine_Onprem_Client_NIC.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}
resource virtualMachine_Onprem_Client_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = if (LeaveThisAsFalse) {
  name: '${virtualMachine_Onprem_Client_Name}-nic'
  location: SourceLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetwork_Source.outputs.general_SubnetID
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
  }
}
resource virtualMachine_Onprem_Client_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = if (LeaveThisAsFalse) {
  parent: virtualMachine_Onprem_Client
  name: 'installcustomscript'
  location: SourceLocation
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [ 
        'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2025_ConfigScript.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type General'
    }
  }
}
// End of onprem_clientVM
