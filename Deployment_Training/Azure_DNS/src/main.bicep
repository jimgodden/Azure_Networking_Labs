@description('Azure Datacenter location for all resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param vmSize string = 'Standard_D2as_v4' // 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = false

@description('''
Storage account name restrictions:
- Storage account names must be between 3 and 24 characters in length and may contain numbers and lowercase letters only.
- Your storage account name must be unique within Azure. No two storage accounts can have the same name.
''')
@minLength(3)
@maxLength(24)
param storageAccount_Name string = 'Insert Unique Name Here'

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

param tagValues object = {
  Training: 'AzureDNS'
}

@description('SKU of the Virtual Network Gateway')
var virtualNetworkGateway_SKU = 'VpnGw1'

var virtualMachine_ScriptFile = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2025_ConfigScript.ps1'

module Hub_VirtualNetwork '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'Hub_VirtualNetwork'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: location
    virtualNetwork_Name: 'Hub_VNet'
    tagValues: tagValues
  }
}

module Spoke_VirtualNetwork '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'Spoke_VirtualNetwork'
  params: {
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    location: location
    virtualNetwork_Name: 'Spoke_VNet'
    tagValues: tagValues
  }
}

module Hub_To_Spoke_Peering '../../../modules/Microsoft.Network/VirtualNetworkPeeringHub2Spoke.bicep' = {
  name: 'Hub_To_Spoke_Peering'
  params: {
    virtualNetwork_Hub_Name: Hub_VirtualNetwork.outputs.virtualNetwork_Name
    virtualNetwork_Spoke_Name: Spoke_VirtualNetwork.outputs.virtualNetwork_Name
  }
  dependsOn: [
    Hub_VirtualNetworkGateway
  ]
}


// Start of Hub-ClientVM
var Hub_VirtualMachine_Client_Name = 'Hub-clientVM'
resource Hub_VirtualMachine_Client 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: Hub_VirtualMachine_Client_Name
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
        name: '${Hub_VirtualMachine_Client_Name}_OsDisk_1'
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
      computerName: Hub_VirtualMachine_Client_Name
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
          id: Hub_VirtualMachine_Client_NIC.id
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
resource Hub_VirtualMachine_Client_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${Hub_VirtualMachine_Client_Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: cidrHost( Hub_VirtualNetwork.outputs.general_Subnet_AddressPrefix, 3 )
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: Hub_VirtualNetwork.outputs.general_SubnetID
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
resource Hub_VirtualMachine_Client_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: Hub_VirtualMachine_Client
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
  tags: tagValues
}
// End of Hub-ClientVM




// Start of Spoke-ClientVM
var Spoke_VirtualMachine_Client_Name = 'Spoke-ClientVM'
resource Spoke_VirtualMachine_Client 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: Spoke_VirtualMachine_Client_Name
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
        name: '${Spoke_VirtualMachine_Client_Name}_OsDisk_1'
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
      computerName: Spoke_VirtualMachine_Client_Name
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
          id: Spoke_VirtualMachine_Client_NIC.id
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
resource Spoke_VirtualMachine_Client_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${Spoke_VirtualMachine_Client_Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: cidrHost( Spoke_VirtualNetwork.outputs.general_Subnet_AddressPrefix, 3 )
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: Spoke_VirtualNetwork.outputs.general_SubnetID
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
  }
  dependsOn: [
    Hub_To_Spoke_Peering
  ]
  tags: tagValues
}
resource Spoke_VirtualMachine_Client_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: Spoke_VirtualMachine_Client
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
  tags: tagValues
}
// End of Spoke-ClientVM




resource StorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccount_Name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: false
    publicNetworkAccess: 'Enabled'
    allowCrossTenantReplication: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
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

resource StorageAccount_BlobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: StorageAccount
  name: 'default'
  properties: {
    changeFeed: {
      enabled: false
    }
    restorePolicy: {
      enabled: false
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: true
      days: 7
    }
    isVersioningEnabled: false
  }
}

resource StorageAccount_PrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'StorageAccount_PrivateEndpoint'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'PrivateEndpoint_to_StorageAccount'
        properties: {
          privateLinkServiceId: StorageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    subnet: {
      id: Hub_VirtualNetwork.outputs.privateEndpoint_SubnetID
    }
  }
  tags: tagValues
}

module Bastion '../../../modules/Microsoft.Network/BastionEverything.bicep' = {
  name: 'Bastion'
  params: {
    location: location
    bastion_name: 'Bastion'
    peered_VirtualNetwork_Ids: [
      Hub_VirtualNetwork.outputs.virtualNetwork_ID
      Spoke_VirtualNetwork.outputs.virtualNetwork_ID
      OnPrem_VirtualNetwork.outputs.virtualNetwork_ID
    ]
    virtualNetwork_AddressPrefix: '10.240.0.0/24'
  }
}

module OnPrem_VirtualNetwork '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'OnPrem_VNet'
  params: {
    virtualNetwork_AddressPrefix: '10.100.0.0/16'
    location: location
    virtualNetwork_Name: 'OnPrem_VNet'
    tagValues: tagValues
  }
}


// Start of OnPrem_dnsVM
var OnPrem_VirtualMachine_Dns_Name = 'OnPrem-dnsVM'
resource OnPrem_VirtualMachine_Dns 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: OnPrem_VirtualMachine_Dns_Name
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
        name: '${OnPrem_VirtualMachine_Dns_Name}_OsDisk_1'
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
      computerName: OnPrem_VirtualMachine_Dns_Name
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
          id: OnPrem_VirtualMachine_Dns_NIC.id
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
resource OnPrem_VirtualMachine_Dns_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${OnPrem_VirtualMachine_Dns_Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: cidrHost( OnPrem_VirtualNetwork.outputs.general_Subnet_AddressPrefix, 3 )
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: OnPrem_VirtualNetwork.outputs.general_SubnetID
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
resource OnPrem_VirtualMachine_Dns_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: OnPrem_VirtualMachine_Dns
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
  tags: tagValues
}
// End of OnPrem_dnsVM


// Start of OnPrem_clientVM
var OnPrem_VirtualMachine_Client_Name = 'OnPrem-clientVM'
resource OnPrem_VirtualMachine_Client 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: OnPrem_VirtualMachine_Client_Name
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
        name: '${OnPrem_VirtualMachine_Client_Name}_OsDisk_1'
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
      computerName: OnPrem_VirtualMachine_Client_Name
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
          id: OnPrem_VirtualMachine_Client_NIC.id
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
resource OnPrem_VirtualMachine_Client_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${OnPrem_VirtualMachine_Client_Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: cidrHost( OnPrem_VirtualNetwork.outputs.general_Subnet_AddressPrefix, 4 )
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: OnPrem_VirtualNetwork.outputs.general_SubnetID
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
resource OnPrem_VirtualMachine_Client_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: OnPrem_VirtualMachine_Client
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
  tags: tagValues
}
// End of OnPrem_clientVM

module OnPrem_VirtualNetworkGateway '../../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'OnPrem_VNG'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65530
    virtualNetworkGateway_Name: 'OnPrem_VNG'
    virtualNetworkGateway_Subnet_ResourceID: OnPrem_VirtualNetwork.outputs.gateway_SubnetID
    virtualNetworkGateway_SKU: virtualNetworkGateway_SKU
    tagValues: tagValues
  }
}

module Hub_VirtualNetworkGateway '../../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'Hub_VNG'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65531
    virtualNetworkGateway_Name: 'Hub_VNG'
    virtualNetworkGateway_Subnet_ResourceID: Hub_VirtualNetwork.outputs.gateway_SubnetID
    virtualNetworkGateway_SKU: virtualNetworkGateway_SKU
    tagValues: tagValues
  }
}

// Connections to the other Virtual Network Gateway
module OnPrem_VNG_Conn '../../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'OnPrem_VNG_conn'
  params: {
    vpn_Destination_BGPIPAddress: Hub_VirtualNetworkGateway.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_ASN: Hub_VirtualNetworkGateway.outputs.virtualNetworkGateway_ASN
    virtualNetworkGateway_ID: OnPrem_VirtualNetworkGateway.outputs.virtualNetworkGateway_ResourceID
    location: location
    vpn_Destination_Name: 'Hub'
    vpn_SharedKey: vpn_SharedKey
    vpn_Destination_PublicIPAddress: Hub_VirtualNetworkGateway.outputs.virtualNetworkGateway_PublicIPAddress
    tagValues: tagValues
  }
}

module Hub_VNG_Conn '../../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'Hub_VNG_conn'
  params: {
    vpn_Destination_BGPIPAddress: OnPrem_VirtualNetworkGateway.outputs.virtualNetworkGateway_BGPAddress
    vpn_Destination_ASN: OnPrem_VirtualNetworkGateway.outputs.virtualNetworkGateway_ASN
    virtualNetworkGateway_ID: Hub_VirtualNetworkGateway.outputs.virtualNetworkGateway_ResourceID
    location: location
    vpn_Destination_Name: 'OnPrem'
    vpn_SharedKey: vpn_SharedKey
    vpn_Destination_PublicIPAddress: OnPrem_VirtualNetworkGateway.outputs.virtualNetworkGateway_PublicIPAddress
    tagValues: tagValues
  }
}
