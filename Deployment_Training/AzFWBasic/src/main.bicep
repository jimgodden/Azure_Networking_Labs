@description('Azure Datacenter location for the Hub and Spoke A resources')
var location = resourceGroup().location

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

@minLength(6)
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
param storageAccount_Name string

param tagValues object = {
  Training: 'AzureFirewall'
}

resource networkSecurityGroup_Generic 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'genericNSG'
  location: location
  tags: tagValues
}

module natGateway_Hub '../../../modules/Microsoft.Network/NATGateway.bicep' = {
  name: 'natGateway_Hub'
  params: {
    location: location
    natGateway_Name: 'NATGateway_Hub'
  }
}

resource virtualNetwork_Hub 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'hub_VNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'General'
        properties: {
          addressPrefix: '10.0.0.0/24'
          routeTable: {
            id: routeTable_Hub.id
          }
          networkSecurityGroup: {
            id: networkSecurityGroup_Generic.id
          }
          natGateway: {
            id: natGateway_Hub.outputs.natGateway_Id
          }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          routeTable: {
            id: routeTable_Hub.id
          }
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
        }
      }
    ]
  }
  tags: tagValues
}

resource routeTable_Hub 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'hub_RouteTable'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'toSpokeA'
        properties: {
          addressPrefix: '10.1.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
      {
        name: 'toSpokeB'
        properties: {
          addressPrefix: '10.2.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
    ]
  }
  tags: tagValues
}

module natGateway_SpokeA '../../../modules/Microsoft.Network/NATGateway.bicep' = {
  name: 'natGateway_SpokeA'
  params: {
    location: location
    natGateway_Name: 'NATGateway_SpokeA'
  }
}

resource virtualNetwork_SpokeA 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'spokeA_VNet'
  location: location
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
          routeTable: {
            id: routeTable_SpokeA.id
          }
          networkSecurityGroup: {
            id: networkSecurityGroup_Generic.id
          }
          natGateway: {
            id: natGateway_SpokeA.outputs.natGateway_Id
          }
        }
      }
    ]
  }
  tags: tagValues
}

resource routeTable_SpokeA 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'spokeA_RouteTable'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'toHub'
        properties: {
          addressPrefix: '10.0.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
      {
        name: 'toSpokeB'
        properties: {
          addressPrefix: '10.2.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
      {
        name: 'toOnPrem'
        properties: {
          addressPrefix: '10.100.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
      {
        name: 'toGoogle'
        properties: {
          addressPrefix: '8.8.8.8/32'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
    ]
  }
  tags: tagValues
}

module natGateway_SpokeB '../../../modules/Microsoft.Network/NATGateway.bicep' = {
  name: 'natGateway_SpokeB'
  params: {
    location: location
    natGateway_Name: 'NATGateway_SpokeB'
  }
}

resource virtualNetwork_SpokeB 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'spokeB_VNet'
  location: location
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
          routeTable: {
            id: routeTable_SpokeB.id
          }
          networkSecurityGroup: {
            id: networkSecurityGroup_Generic.id
          }
          natGateway: {
            id: natGateway_SpokeB.outputs.natGateway_Id
          }
        }
      }
      {
        name: 'PrivateEndpoint'
        properties: {
          addressPrefix: '10.2.1.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup_Generic.id
          }
        }
      }
    ]
  }
  tags: tagValues
}

resource routeTable_SpokeB 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'spokeB_RouteTable'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'toHub'
        properties: {
          addressPrefix: '10.0.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
      {
        name: 'toSpokeA'
        properties: {
          addressPrefix: '10.1.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
      {
        name: 'toOnPrem'
        properties: {
          addressPrefix: '10.100.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
    ]
  }
  tags: tagValues
}

module peerings_Hub_to_Spokes_NoGateway '../../../modules/Microsoft.Network/VirtualNetworkPeeringsHub2SpokesNoGateway.bicep' = {
  name: 'peerings_Hub_to_Spokes_NoGateway'
  params: {
    virtualNetwork_Hub_Id: virtualNetwork_Hub.id
    virtualNetwork_Spoke_Ids: [
      virtualNetwork_SpokeA.id
      virtualNetwork_SpokeB.id
    ]
  }
  dependsOn: [
    bastion
  ]
}

// Start of hub-DnsVM
var virtualMachine_Hub_Dns_Name = 'hub-dnsVM'
resource virtualMachine_Hub_Dns 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachine_Hub_Dns_Name
  location: location
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
        name: '${virtualMachine_Hub_Dns_Name}_OsDisk_1'
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
      computerName: virtualMachine_Hub_Dns_Name
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
          id: virtualMachine_Hub_Dns_NIC.id
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
resource virtualMachine_Hub_Dns_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${virtualMachine_Hub_Dns_Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: '10.0.0.4'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: virtualNetwork_Hub.properties.subnets[0].id
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
resource virtualMachine_Hub_Dns_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_Hub_Dns
  name: 'installcustomscript'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [ 
        'https://supportability.visualstudio.com/_git/AzureNetworking?path=/.LabBoxRepo/Hybrid/AzFW_Basic-Training/WinServ2025_ConfigScript.ps1'
        // 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2025_ConfigScript.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type DNS'
    }
  }
  tags: tagValues
}
// End of hub-DnsVM


// Start of spokeA-ClientVM
var virtualMachine_SpokeA_Client_Name = 'spokeA-clientVM'
resource virtualMachine_SpokeA_Client 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachine_SpokeA_Client_Name
  location: location
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
        name: '${virtualMachine_SpokeA_Client_Name}_OsDisk_1'
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
      computerName: virtualMachine_SpokeA_Client_Name
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
          id: virtualMachine_SpokeA_Client_NIC.id
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
resource virtualMachine_SpokeA_Client_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${virtualMachine_SpokeA_Client_Name}-nic'
  location: location
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
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
  }
  tags: tagValues
}
resource virtualMachine_SpokeA_Client_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_SpokeA_Client
  name: 'installcustomscript'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [ 
        'https://supportability.visualstudio.com/_git/AzureNetworking?path=/.LabBoxRepo/Hybrid/AzFW_Basic-Training/WinServ2025_ConfigScript.ps1'
        // 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2025_ConfigScript.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type General'
    }
  }
  tags: tagValues
}
// End of spokeA-ClientVM

// Start of spokeB-IisVM
var virtualMachine_SpokeB_Iis_Name = 'spokeB-iisVM'
resource virtualMachine_SpokeB_Iis 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachine_SpokeB_Iis_Name
  location: location
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
resource virtualMachine_SpokeB_Iis_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${virtualMachine_SpokeB_Iis_Name}-nic'
  location: location
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
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [ 
        'https://supportability.visualstudio.com/_git/AzureNetworking?path=/.LabBoxRepo/Hybrid/AzFW_Basic-Training/WinServ2025_ConfigScript.ps1'
        // 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2025_ConfigScript.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type WebServer'
    }
  }
  tags: tagValues
}
// End of spokeB-IisVM

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccount_Name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: true
    publicNetworkAccess: 'Enabled'
    allowCrossTenantReplication: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Deny'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
  tags: tagValues
}
module storageAccount_Blob_PrivateEndpoint '../../../modules/Microsoft.Network/PrivateEndpoint.bicep' = {
  name: 'storageAccount_Blob_PrivateEndpoint'
  params: {
    location: location
    groupID: 'blob'
    privateDNSZone_Name: 'privatelink.blob.${environment().suffixes.storage}'
    privateEndpoint_Name: 'spokeB_${storageAccount_Name}_blob_PrivateEndpoint'
    privateEndpoint_SubnetID: virtualNetwork_SpokeB.properties.subnets[1].id
    privateLinkServiceId: storageAccount.id
    virtualNetwork_IDs: [
      virtualNetwork_Hub.id
      virtualNetwork_SpokeA.id
      virtualNetwork_SpokeB.id
    ]
  }
}

module bastion '../../../modules/Microsoft.Network/BastionEverything.bicep' = {
  name: 'AllBastionResources'
  params: {
    location: location
    peered_VirtualNetwork_Ids: [ 
      virtualNetwork_Hub.id
      virtualNetwork_SpokeA.id
      virtualNetwork_SpokeB.id
      virtualNetwork_OnPrem.id
    ] 
    bastion_name: 'Bastion'
    virtualNetwork_AddressPrefix: '10.200.0.0/24'
  }
}

module natGateway_OnPrem '../../../modules/Microsoft.Network/NATGateway.bicep' = {
  name: 'natGateway_OnPrem'
  params: {
    location: location
    natGateway_Name: 'NATGateway_OnPrem'
  }
}

resource virtualNetwork_OnPrem 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'onprem_VNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.100.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'General'
        properties: {
          addressPrefix: '10.100.0.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup_Generic.id
          }
          natGateway: {
            id: natGateway_OnPrem.outputs.natGateway_Id
          }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.100.1.0/24'
        }
      }
    ]
  }
}

// Start of onprem_dnsVM
var virtualMachine_Onprem_Dns_Name = 'onprem-dnsVM'
resource virtualMachine_Onprem_Dns 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachine_Onprem_Dns_Name
  location: location
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
        name: '${virtualMachine_Onprem_Dns_Name}_OsDisk_1'
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
      computerName: virtualMachine_Onprem_Dns_Name
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
          id: virtualMachine_Onprem_Dns_NIC.id
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
resource virtualMachine_Onprem_Dns_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${virtualMachine_Onprem_Dns_Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: '10.100.0.4'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: virtualNetwork_OnPrem.properties.subnets[0].id
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
resource virtualMachine_Onprem_Dns_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_Onprem_Dns
  name: 'installcustomscript'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [ 
        'https://supportability.visualstudio.com/_git/AzureNetworking?path=/.LabBoxRepo/Hybrid/AzFW_Basic-Training/WinServ2025_ConfigScript.ps1'
        // 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2025_ConfigScript.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type DNS'
    }
  }
  tags: tagValues
}
// End of onprem_dnsVM

// Start of onprem_clientVM
var virtualMachine_Onprem_Client_Name = 'onprem-clientVM'
resource virtualMachine_Onprem_Client 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachine_Onprem_Client_Name
  location: location
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
  tags: tagValues
}
resource virtualMachine_Onprem_Client_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${virtualMachine_Onprem_Client_Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: '10.100.0.5'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: virtualNetwork_OnPrem.properties.subnets[0].id
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
resource virtualMachine_Onprem_Client_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_Onprem_Client
  name: 'installcustomscript'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [ 
        'https://supportability.visualstudio.com/_git/AzureNetworking?path=/.LabBoxRepo/Hybrid/AzFW_Basic-Training/WinServ2025_ConfigScript.ps1'
        // 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2025_ConfigScript.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type General'
    }
  }
  tags: tagValues
}
// End of onprem_clientVM

module onprem_to_Hub_VirtualNetworkGateways_and_Connections '../../../modules/Microsoft.Network/VirtualNetworkGatewaysAndConnections.bicep' = {
  name: 'onprem_to_Hub_VirtualNetworkGateways_and_Connections'
  params: {
    location_VirtualNetworkGateway1: location
    asn_VirtualNetworkGateway1: 65000
    name_VirtualNetworkGateway1: 'onprem_VNG'
    subnetId_VirtualNetworkGateway1: virtualNetwork_OnPrem.properties.subnets[1].id
    location_VirtualNetworkGateway2: location
    asn_VirtualNetworkGateway2: 65001
    name_VirtualNetworkGateway2: 'hub_VNG'
    subnetId_VirtualNetworkGateway2: virtualNetwork_Hub.properties.subnets[1].id
    vpn_SharedKey: vpn_SharedKey
  }
  dependsOn: [
    peerings_Hub_to_Spokes_NoGateway
  ]
}

module peerings_Hub_to_Spokes '../../../modules/Microsoft.Network/VirtualNetworkPeeringsHub2Spokes.bicep' = {
  name: 'peerings_Hub_to_Spokes'
  params: {
    virtualNetwork_Hub_Id: virtualNetwork_Hub.id
    virtualNetwork_Spoke_Ids: [
      virtualNetwork_SpokeA.id
      virtualNetwork_SpokeB.id
    ]
  }
  dependsOn: [
    onprem_to_Hub_VirtualNetworkGateways_and_Connections
  ]
}

resource azureFirewall_PIP 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: 'AzFW_PIP'
  location: location
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

resource azureFirewall_Management_PIP 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: 'AzFW_Management_PIP'
  location: location
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
