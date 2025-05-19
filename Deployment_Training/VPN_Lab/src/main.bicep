@description('Azure Datacenter location for the source resources')
var location = resourceGroup().location

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
//param acceleratedNetworking bool = true
var acceleratedNetworking = false

@description('SKU of the Virtual Network Gateway')
param virtualNetworkGateway_SKU string = 'VpnGw1'

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

// var virtualMachine_ScriptFile = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2025_ConfigScript.ps1'
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

// Start of VM-A
var virtualMachine_A_Name = 'VM-A'
resource virtualMachine_A 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachine_A_Name
  location: location
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
        name: '${virtualMachine_A_Name}_OsDisk_1'
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
      computerName: virtualMachine_A_Name
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
          id: virtualMachine_A_NIC.id
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
resource virtualMachine_A_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${virtualMachine_A_Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetworkA.outputs.general_SubnetID
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
  }
}
resource virtualMachine_A_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_A
  name: 'installcustomscript'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [ 
        virtualMachine_ScriptFile
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type General'
    }
  }
}
// End of VM-A

// Start of VM-B
var virtualMachine_B_Name = 'VM-B'
resource virtualMachine_B 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachine_B_Name
  location: location
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
        name: '${virtualMachine_B_Name}_OsDisk_1'
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
      computerName: virtualMachine_B_Name
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
          id: virtualMachine_B_NIC.id
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
resource virtualMachine_B_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${virtualMachine_B_Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetworkB.outputs.general_SubnetID
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
  }
}
resource virtualMachine_B_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_B
  name: 'installcustomscript'
  location: location
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
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type DNS'
    }
  }
}
// End of VM-B

// Start of VM-C
var virtualMachine_C_Name = 'VM-C'
resource virtualMachine_C 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachine_C_Name
  location: location
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
        name: '${virtualMachine_C_Name}_OsDisk_1'
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
      computerName: virtualMachine_C_Name
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
          id: virtualMachine_C_NIC.id
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
resource virtualMachine_C_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${virtualMachine_C_Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetworkC.outputs.general_SubnetID
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
  }
}
resource virtualMachine_C_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_C
  name: 'installcustomscript'
  location: location
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
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type DNS'
    }
  }
}
// End of VM-C
