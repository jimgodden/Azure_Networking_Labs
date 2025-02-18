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
param acceleratedNetworking bool = true

@description('SKU for the Azure Firewall')
param azureFirewall_SKU string = 'Premium'

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

var virtualMachine_ScriptFile = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2025_ConfigScript.ps1'

param tagValues object = {
  Training: 'AzureFirewall'
}


module virtualNetwork_Hub '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'hub_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: location
    virtualNetwork_Name: 'hub_VNet'
  }
}

module virtualNetwork_SpokeA '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'spokeA_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    routeTable_disableBgpRoutePropagation: true
    location: location
    virtualNetwork_Name: 'spokeA_VNet'
  }
}

module virtualNetwork_SpokeB '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'spokeB_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.2.0.0/16'
    routeTable_disableBgpRoutePropagation: true
    location: location
    virtualNetwork_Name: 'spokeB_VNet'
  }
}

module hub_To_SpokeA_Peering '../../../modules/Microsoft.Network/VirtualNetworkPeeringHub2Spoke.bicep' = {
  name: 'hubToSpokeAPeering'
  params: {
    virtualNetwork_Hub_Name: virtualNetwork_Hub.outputs.virtualNetwork_Name
    virtualNetwork_Spoke_Name: virtualNetwork_SpokeA.outputs.virtualNetwork_Name
  }
  dependsOn: [
    Hub_to_OnPrem_conn
    OnPrem_to_Hub_conn
  ]
}

module hub_To_SpokeB_Peering '../../../modules/Microsoft.Network/VirtualNetworkPeeringHub2Spoke.bicep' = {
  name: 'hubToSpokeBPeering'
  params: {
    virtualNetwork_Hub_Name: virtualNetwork_Hub.outputs.virtualNetwork_Name
    virtualNetwork_Spoke_Name: virtualNetwork_SpokeB.outputs.virtualNetwork_Name
  }
  dependsOn: [
    Hub_to_OnPrem_conn
    OnPrem_to_Hub_conn
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
            id: virtualNetwork_Hub.outputs.general_SubnetID
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
      fileUris: [ virtualMachine_ScriptFile]
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
            id: virtualNetwork_SpokeA.outputs.general_SubnetID
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
      fileUris: [ virtualMachine_ScriptFile ]
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
            id: virtualNetwork_SpokeB.outputs.general_SubnetID
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
      fileUris: [ virtualMachine_ScriptFile ]
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

// resource storageAccount_BlobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
//   parent: storageAccount
//   name: 'default'
//   properties: {
//     changeFeed: {
//       enabled: false
//     }
//     restorePolicy: {
//       enabled: false
//     }
//     containerDeleteRetentionPolicy: {
//       enabled: true
//       days: 7
//     }
//     cors: {
//       corsRules: []
//     }
//     deleteRetentionPolicy: {
//       allowPermanentDelete: false
//       enabled: true
//       days: 7
//     }
//     isVersioningEnabled: false
//   }
// }

module storageAccount_Blob_PrivateEndpoint '../../../modules/Microsoft.Network/PrivateEndpoint.bicep' = {
  name: 'storageAccount_Blob_PrivateEndpoint'
  params: {
    location: location
    groupID: 'blob'
    privateDNSZone_Name: 'privatelink.blob.${environment().suffixes.storage}'
    privateEndpoint_Name: 'spokeB_${storageAccount_Name}_blob_PrivateEndpoint'
    privateEndpoint_SubnetID: virtualNetwork_SpokeB.outputs.privateEndpoint_SubnetID
    privateLinkServiceId: storageAccount.id
    virtualNetwork_IDs: [
      virtualNetwork_Hub.outputs.virtualNetwork_ID
      virtualNetwork_SpokeA.outputs.virtualNetwork_ID
      virtualNetwork_SpokeB.outputs.virtualNetwork_ID
    ]
  }
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

module azureFirewall '../../../modules/Microsoft.Network/AzureFirewall.bicep' = {
  name: 'hubAzureFirewall'
  params: {
    azureFirewall_ManagementSubnet_ID: virtualNetwork_Hub.outputs.azureFirewallManagement_SubnetID
    azureFirewall_Name: 'hub_AzFW'
    azureFirewall_SKU: azureFirewall_SKU
    azureFirewall_Subnet_ID: virtualNetwork_Hub.outputs.azureFirewall_SubnetID
    azureFirewallPolicy_Name: 'hub_AzFWPolicy'
    location: location
  }
  dependsOn: [
    Hub_to_OnPrem_conn
    OnPrem_to_Hub_conn
  ]
}

module udrToAzFW_Hub '../../../modules/Microsoft.Network/RouteTable.bicep' = {
  name: 'udrToAzFW_Hub'
  params: {
    addressPrefixs: [
      '10.0.0.0/8'
    ]
    nextHopType: 'VirtualAppliance'
    routeTable_Name: virtualNetwork_Hub.outputs.routeTable_Name
    routeTableRoute_Name: 'toAzFW'
    nextHopIpAddress: '10.0.6.4' // hardcode IP Address
  }
}

module udrToAzFW_SpokeA '../../../modules/Microsoft.Network/RouteTable.bicep' = {
  name: 'udrToAzFW_SpokeA'
  params: {
    addressPrefixs: [
      '10.0.0.0/8'
    ]
    nextHopType: 'VirtualAppliance'
    routeTable_Name: virtualNetwork_SpokeA.outputs.routeTable_Name
    routeTableRoute_Name: 'toAzFW'
    nextHopIpAddress: '10.0.6.4'
  }
}

module udrToAzFW_SpokeB '../../../modules/Microsoft.Network/RouteTable.bicep' = {
  name: 'udrToAzFW_SpokeB'
  params: {
    addressPrefixs: [
      '10.0.0.0/8'
    ]
    nextHopType: 'VirtualAppliance'
    routeTable_Name: virtualNetwork_SpokeB.outputs.routeTable_Name
    routeTableRoute_Name: 'toAzFW'
    nextHopIpAddress: '10.0.6.4'
  }
}

module Bastion '../../../modules/Microsoft.Network/BastionEverything.bicep' = {
  name: 'AllBastionResources'
  params: {
    location: location
    peered_VirtualNetwork_Ids: [ 
      virtualNetwork_Hub.outputs.virtualNetwork_ID
      virtualNetwork_SpokeA.outputs.virtualNetwork_ID
      virtualNetwork_SpokeB.outputs.virtualNetwork_ID
      virtualNetwork_OnPremHub.outputs.virtualNetwork_ID
    ] 
    bastion_name: 'Bastion'
    virtualNetwork_AddressPrefix: '10.200.0.0/24'
  }
}

module virtualNetwork_OnPremHub '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'onprem_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.100.0.0/16'
    location: location
    virtualNetwork_Name: 'onprem_VNet'
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
            id: virtualNetwork_OnPremHub.outputs.general_SubnetID
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
      fileUris: [ virtualMachine_ScriptFile ]
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
            id: virtualNetwork_OnPremHub.outputs.general_SubnetID
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
      fileUris: [ virtualMachine_ScriptFile ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type General'
    }
  }
  tags: tagValues
}

module virtualNetworkGateway_OnPrem '../../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'OnPremVirtualNetworkGateway'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65000
    virtualNetworkGateway_Name: 'onprem_VNG'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork_OnPremHub.outputs.gateway_SubnetID
  }
}

module virtualNetworkGateway_Hub '../../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'HubVirtualNetworkGateway'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65001
    virtualNetworkGateway_Name: 'hub_VNG'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork_Hub.outputs.gateway_SubnetID
  }
}

module OnPrem_to_Hub_conn '../../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'OnPrem_to_Hub_conn'
  params: {
    location: location
    virtualNetworkGateway_ID: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_ASN: virtualNetworkGateway_Hub.outputs.virtualNetworkGateway_ASN
    vpn_Destination_BGPIPAddress: virtualNetworkGateway_Hub.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_Name: virtualNetworkGateway_Hub.outputs.virtualNetworkGateway_Name
    vpn_Destination_PublicIPAddress: virtualNetworkGateway_Hub.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
  }
}

module Hub_to_OnPrem_conn '../../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'Hub_to_OnPrem_conn'
  params: {
    location: location
    virtualNetworkGateway_ID: virtualNetworkGateway_Hub.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_ASN: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_ASN
    vpn_Destination_BGPIPAddress: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_Name: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_Name
    vpn_Destination_PublicIPAddress: virtualNetworkGateway_OnPrem.outputs.virtualNetworkGateway_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
  }
}
