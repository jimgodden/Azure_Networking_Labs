param location string

@maxLength(15)
@description('Name of the Virtual Machine')
param virtualMachine_Name string

@allowed([
  '2025-datacenter-azure-edition'
  '2022-datacenter-g2'
  '2022-datacenter'
  '2019-datacenter-gensecond'
  '2019-datacenter'
  '2016-datacenter-gensecond'
  '2016-datacenter'
])
@description('The version of Windows Server to deploy.')
param windowsServerVersion string = '2025-datacenter-azure-edition'

@description('''Size of the Virtual Machine
Examples:
B2ms - 2 Core 8GB Ram - Cannot use Accelerated Networking
D2as_v5 2 Core 8GB Ram - Uses Accelerated Networking''')
param vmSize string

@description('Admin Username for the Virtual Machine')
param virtualMachine_AdminUsername string

@description('Password for the Virtual Machine Admin User')
@secure()
param virtualMachine_AdminPassword string

@description('Name of the Virtual Machines Network Interface')
param networkInterface_Name string = '${virtualMachine_Name}_NetworkInterface'

@description('True enables Accelerated Networking and False disabled it.  Not all sizes support Accel Net')
param acceleratedNetworking bool

@description('The Resource ID of the subnet to which the Network Interface will be assigned.')
param subnet_ID string

@description('Set this to true to install commonly used tools like Wireshark')
param installTools bool = true

@description('Enables the Virtual Machine to be joined to an Entra Domain')
param entraConnect bool = false

@description('Adds a Public IP to the Network Interface of the Virtual Machine')
param addPublicIPAddress bool = false

@description('Sets the allocation mode of the IP Address of the Network Interface to either Dynamic or Static.')
@allowed([
  'Dynamic'
  'Static'
])
param privateIPAllocationMethod string = 'Dynamic'

@description('Enter the Static IP Address here if privateIPAllocationMethod is set to Static.')
param privateIPAddress string = ''

param enableIPForwarding bool = true

param tagValues object = {}

resource virtualMachine_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = if (installTools) {
  parent: virtualMachine
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
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type General'
    }
  }
  tags: tagValues
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachine_Name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  zones: [
    '1'
  ]
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
        sku: windowsServerVersion
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        name: '${virtualMachine_Name}_OsDisk_1'
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
      computerName: virtualMachine_Name
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
          // enableHotpatching: true some windows versions do not support this (2019)
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
          id: nic.id
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

// resource virtualMachine_OS_Disk 'Microsoft.Compute/disks@2025-01-02' = {
//   name: '${virtualMachine_Name}_OsDisk_1'
//   sku: {
//     name: 'Premium_LRS'
//   }
//   location: location
//   properties: {
//     creationData: {
//       createOption: 'FromImage'
//     }
//   }
// }

resource virtualMachine_NetworkWatcherExtension 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  parent: virtualMachine
  name: 'AzureNetworkWatcherExtension'
  location: location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.NetworkWatcher'
    type: 'NetworkWatcherAgentWindows'
    typeHandlerVersion: '1.4'
  }
  tags: tagValues
}

resource AADLoginForWindows 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = if (entraConnect) {
  parent: virtualMachine
  name: 'AADLoginForWindows'
  location: location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    settings: {
      mdmId: ''
    }
  }
  tags: tagValues
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2024-01-01' = if (addPublicIPAddress){
  name: '${virtualMachine_Name}_pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'  
  }
  tags: tagValues
}

resource nic 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: networkInterface_Name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: privateIPAddress
          privateIPAllocationMethod: privateIPAllocationMethod
          publicIPAddress: addPublicIPAddress ? { id: publicIPAddress.id } : null
          subnet: {
            id: subnet_ID
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
    enableIPForwarding: enableIPForwarding
  }
  tags: tagValues
}

output virtualMachine_Name string = virtualMachine.name
output virtualMachine_Id string = virtualMachine.id

output networkInterface_Name string = nic.name
output networkInterface_ID string = nic.id

output networkInterface_IPConfig0_Name string = nic.properties.ipConfigurations[0].name
output networkInterface_IPConfig0_ID string = nic.properties.ipConfigurations[0].id
output networkInterface_PrivateIPAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress

output networkInterface_PublicIPAddress string = addPublicIPAddress ? publicIPAddress.properties.ipAddress : ''
