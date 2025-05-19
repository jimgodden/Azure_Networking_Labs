param location string = resourceGroup().location

@description('Name of the App Service')
param site_Name string = 'anptestsite${substring(uniqueString(resourceGroup().id), 0, 5)}'

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Password for the Virtual Machine Admin User')
param virtualMachine_Size string = 'Standard_D2as_v4' // 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
var acceleratedNetworking = false

param isUsingAzureFirewall bool = false

param azureFirewall_SKU string = 'Standard'

var fileUri = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2025_ConfigScript.ps1'

var virtualMachine_Website_DomainName = 'contoso.com'

param tagValues object = {
  Sandbox: 'ApplicationGateway'
}

module virtualNetwork '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'VirtualNetwork'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: location
    virtualNetwork_Name: 'VirutalNetwork'
  }
}

// Start of clientVM
var virtualMachine_Client_Name = 'clientVM'
resource virtualMachine_Client 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachine_Client_Name
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
        name: '${virtualMachine_Client_Name}_OsDisk_1'
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
      computerName: virtualMachine_Client_Name
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
          id: virtualMachine_Client_NIC.id
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
resource virtualMachine_Client_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${virtualMachine_Client_Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetwork.outputs.general_SubnetID
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
  }
  tags: tagValues
}
resource virtualMachine_Client_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_Client
  name: 'installcustomscript'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [ 
        fileUri
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type General'
    }
  }
  tags: tagValues
}
// End of clientVM


module applicationGateway_v2 '../../../modules/Microsoft.Network/ApplicationGateway_v2.bicep' = {
  name: 'applicationGateway_v2'
  params: {
    applicationGateway_Name: 'applicationGateway_v2'
    applicationGateway_PrivateIPAddress: parseCidr(virtualNetwork.outputs.applicationGateway_Subnet_AddressPrefix).lastUsable
    location: location
    applicationGateway_SubnetID: virtualNetwork.outputs.applicationGateway_SubnetID
    backendPoolFQDNs: [
      webApp.outputs.website_FQDN
      '${virtualMachine_WinWeb.name}.${virtualMachine_Website_DomainName}'
      '${virtualMachine_LinuxWeb.name}.${virtualMachine_Website_DomainName}'
    ]
  }
}

module webApp '../../../modules/Microsoft.Web/site.bicep' = {
  name: 'webApp'
  params: {
    appServicePlan_Name: 'asp'
    appServiceSubnet_ID: virtualNetwork.outputs.appService_SubnetID
    location: location
    site_Name: site_Name
    virtualNetwork_Name: virtualNetwork.outputs.virtualNetwork_Name 
  }
}

module privateDNSZone_ContosoDotCom '../../../modules/Microsoft.Network/PrivateDNSZone.bicep' = {
  name: 'privateDNSZone_ContosoDotCom'
  params: {
    privateDNSZone_Name: virtualMachine_Website_DomainName
    virtualNetworkIDs: [virtualNetwork.outputs.virtualNetwork_ID]
    registrationEnabled: true
  }
}

module privatDNSZone_ARecord_ApplicationGateway '../../../modules/Microsoft.Network/PrivateDNSZoneARecord.bicep' = {
  name: 'privatDNSZone_ARecord_ApplicationGateway'
  params: {
    ARecord_name: 'applicationGateway'
    ipv4Address: applicationGateway_v2.outputs.ApplicationGateway_FrontendIP_Private
    PrivateDNSZone_Name: privateDNSZone_ContosoDotCom.outputs.PrivateDNSZone_Name
  }
}

// Start of WinWebVM
var virtualMachine_WinWeb_Name = 'WinWebVM'
resource virtualMachine_WinWeb 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachine_WinWeb_Name
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
        name: '${virtualMachine_WinWeb_Name}_OsDisk_1'
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
      computerName: virtualMachine_WinWeb_Name
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
          id: virtualMachine_WinWeb_NIC.id
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
resource virtualMachine_WinWeb_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${virtualMachine_WinWeb_Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetwork.outputs.general_SubnetID
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
  }
  tags: tagValues
}
resource virtualMachine_WinWeb_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_WinWeb
  name: 'installcustomscript'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [ 
        fileUri
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Type WebServer -FQDN webserverVM.${virtualMachine_Website_DomainName}'
    }
  }
  tags: tagValues
}
// End of WinWebVM

// Start of LinuxWebVM
var virtualMachine_LinuxWeb_Name = 'LinuxWebVM'
resource virtualMachine_LinuxWeb 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: virtualMachine_LinuxWeb_Name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: virtualMachine_Size
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        osType: 'Linux'
        name: '${virtualMachine_LinuxWeb_Name}_OsDisk_1'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        deleteOption: 'Delete'
      }
      dataDisks: []
    }
    osProfile: {
      computerName: virtualMachine_LinuxWeb_Name
      adminUsername: virtualMachine_AdminUsername
      adminPassword: virtualMachine_AdminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'ImageDefault'
          assessmentMode: 'ImageDefault'
        }
      }
      secrets: []
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: virtualMachine_LinuxWeb_NIC.id
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
resource virtualMachine_LinuxWeb_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${virtualMachine_LinuxWeb_Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetwork.outputs.general_SubnetID
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
  }
  tags: tagValues
}
resource virtualMachine_LinuxWeb_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_LinuxWeb
  name: 'installcustomscript'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/Ubuntu20_WebServer_Config.sh'
      ]
    }
    protectedSettings: {
      commandToExecute: './Ubuntu20_WebServer_Config.sh ${virtualMachine_LinuxWeb_Name}.${virtualMachine_Website_DomainName}'
    }
  }
  tags: tagValues
}
// End of LinuxWebVM

module azureFirewall '../../../modules/Microsoft.Network/AzureFirewall.bicep' = if (isUsingAzureFirewall) {
  name: 'azureFirewall'
  params: {
    azureFirewall_Name: 'azureFirewall'
    azureFirewall_SKU: azureFirewall_SKU
    azureFirewall_ManagementSubnet_ID: virtualNetwork.outputs.azureFirewallManagement_SubnetID
    azureFirewallPolicy_Name: 'azureFirewallPolicy'
    azureFirewall_Subnet_ID: virtualNetwork.outputs.azureFirewall_SubnetID
    location: location
  }
  dependsOn: [
    applicationGateway_v2
  ]
}

module bastion '../../../modules/Microsoft.Network/BastionEverything.bicep' = {
  name: 'AllBastionResources'
  params: {
    location: location
    peered_VirtualNetwork_Ids: [ 
      virtualNetwork.outputs.virtualNetwork_ID
    ] 
    bastion_name: 'Bastion'
    virtualNetwork_AddressPrefix: '10.200.0.0/24'
  }
}
