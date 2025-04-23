@description('Azure Datacenter location for SpokeA resources')
var locationA = 'eastus2'

@description('Azure Datacenter location for SpokeB resources')
var locationB = 'centralus'

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@minLength(8)
@description('''Password for the admin account of the Virtual Machines.
Ensure the password meets typical Azure VM password requirements.
''')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param vmSize string = 'Standard_D2as_v4' // 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = false

param tagValues object = {
  Sandbox: 'FrontDoor'
}

var virtualMachine_ScriptFile = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2025_ConfigScript.ps1'


resource networkSecurityGroup_GenericA 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'genericNSGA'
  location: locationA
  properties: {
    securityRules: [
      {
        name: 'AllowHttp'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
          priority: 110
          description: 'Allow HTTP'
        }
      }
      {
        name: 'Allow8080'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '8080'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
          priority: 120
          description: 'Allow HTTP'
        }
      }
      {
        name: 'AllowHttps'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
          priority: 130
          description: 'Allow HTTPS'
        }
      }
    ]
  }
  tags: tagValues
}

resource networkSecurityGroup_GenericB 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'genericNSGB'
  location: locationB
  properties: {
    securityRules: [
      {
        name: 'AllowHttp'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
          priority: 110
          description: 'Allow HTTP'
        }
      }
      {
        name: 'Allow8080'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '8080'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
          priority: 120
          description: 'Allow HTTP'
        }
      }
      {
        name: 'AllowHttps'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
          priority: 130
          description: 'Allow HTTPS'
        }
      }
    ]
  }
  tags: tagValues
}

resource virtualNetwork_SpokeA 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'spokeA_VNet'
  location: locationA
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'General'
        properties: {
          addressPrefix: '10.1.0.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup_GenericA.id
          }
        }
      }
    ]
  }
  tags: tagValues
}

resource virtualNetwork_SpokeB 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'spokeB_VNet'
  location: locationB
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.2.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'General'
        properties: {
          addressPrefix: '10.2.0.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup_GenericB.id
          }
        }
      }
    ]
  }
  tags: tagValues
}


// Start of spokeA-IisVM
var virtualMachine_spokeA_Iis_Name = 'spokeA-iisVM'
resource virtualMachine_spokeA_Iis 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachine_spokeA_Iis_Name
  location: locationA
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
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
        name: '${virtualMachine_spokeA_Iis_Name}_OsDisk_1'
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
      computerName: virtualMachine_spokeA_Iis_Name
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
          id: virtualMachine_spokeA_Iis_NIC.id
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
  tags: tagValues
}
resource virtualMachine_spokeA_Iis_NIC_publicIPAddress 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: '${virtualMachine_spokeA_Iis_Name}_PIP'
  location: locationA
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    ipTags: []
  }
  tags: tagValues
}
resource virtualMachine_spokeA_Iis_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${virtualMachine_spokeA_Iis_Name}-nic'
  location: locationA
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: '10.1.0.4'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: virtualNetwork_SpokeA.properties.subnets[0].id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
          publicIPAddress: { 
            id: virtualMachine_spokeA_Iis_NIC_publicIPAddress.id 
          }
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
  }
  tags: tagValues
}
resource virtualMachine_spokeA_Iis_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_spokeA_Iis
  name: 'installcustomscript'
  location: locationA
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
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type WebServer'
    }
  }
  tags: tagValues
}
// End of spokeA-IisVM


// Start of spokeB-IisVM
var virtualMachine_SpokeB_Iis_Name = 'spokeB-iisVM'
resource virtualMachine_SpokeB_Iis 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachine_SpokeB_Iis_Name
  location: locationB
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
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
        name: '${virtualMachine_SpokeB_Iis_Name}_OsDisk_1'
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
      computerName: virtualMachine_SpokeB_Iis_Name
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
          id: virtualMachine_SpokeB_Iis_NIC.id
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
  tags: tagValues
}
resource virtualMachine_spokeB_Iis_NIC_publicIPAddress 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: '${virtualMachine_SpokeB_Iis_Name}_PIP'
  location: locationB
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    ipTags: []
  }
  tags: tagValues
}
resource virtualMachine_SpokeB_Iis_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${virtualMachine_SpokeB_Iis_Name}-nic'
  location: locationB
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: '10.2.0.4'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: virtualNetwork_SpokeB.properties.subnets[0].id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
          publicIPAddress: {
            id: virtualMachine_spokeB_Iis_NIC_publicIPAddress.id
          }
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
  }
  tags: tagValues
}
resource virtualMachine_SpokeB_Iis_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_SpokeB_Iis
  name: 'installcustomscript'
  location: locationB
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
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type WebServer'
    }
  }
  tags: tagValues
}
// End of spokeB-IisVM

module bastion '../../../modules/Microsoft.Network/BastionEverything.bicep' = {
  name: 'AllBastionResources'
  params: {
    location: locationA
    peered_VirtualNetwork_Ids: [ 
      virtualNetwork_SpokeA.id
      virtualNetwork_SpokeB.id
    ] 
    bastion_name: 'Bastion'
    virtualNetwork_AddressPrefix: '10.200.0.0/24'
  }
}
