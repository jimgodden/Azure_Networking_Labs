param location string

@maxLength(15)
@description('Name of the Virtual Machine')
param virtualMachine_Name string

@description('''Size of the Virtual Machine
Examples:
B2ms - 2 Core 8GB Ram - Cannot use Accelerated Networking
D2as_v5 2 Core 8GB Ram - Uses Accelerated Networking''')
param virtualMachine_Size string

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

@description('''Location of the file to be ran while the Virtual Machine is being created.  Ensure that the path ends with a /
Example: https://example.com/scripts/''')
param virtualMachine_ScriptFileLocation string = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/VNET-Hub-and-Spoke-Merge/scripts/'

@description('''Name of the file to be ran while the Virtual Machine is being created
Example: InitScript.ps1''')
param virtualMachine_ScriptFileName string = 'WinServ2022_General_InitScript.ps1'

@description('Joins the file path and the file name together')
var virtualMachine_ScriptFileUri = '${virtualMachine_ScriptFileLocation}${virtualMachine_ScriptFileName}'

@description(''''Command to execute while the Virtual Machine is being created.
Example:
'powershell -ExecutionPolicy Unrestricted -File ${virtualMachine_ScriptFileName}'
''')
param commandToExecute string = 'powershell -ExecutionPolicy Unrestricted -File ${virtualMachine_ScriptFileName}'


module networkInterface '../../Microsoft.Network/NetworkInterface.bicep' = {
  name: networkInterface_Name
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    networkInterface_Name: networkInterface_Name
    subnet_ID: subnet_ID
  }
}

// resource networkInterface 'Microsoft.Network/networkInterfaces@2022-09-01' = {
//   name: networkInterface_Name
//   location: location
//   properties: {
//     ipConfigurations: [
//       {
//         name: 'ipconfig1'
//         type: 'Microsoft.Network/networkInterfaces/ipConfigurations'
//         properties: {
//           privateIPAllocationMethod: 'Dynamic'
//           subnet: {
//             id: subnet_ID
//           }
//           primary: true
//           privateIPAddressVersion: 'IPv4'
//         }
//       }
//     ]
//     enableAcceleratedNetworking: acceleratedNetworking
//     enableIPForwarding: false
//     disableTcpStateTracking: false
//     nicType: 'Standard'
//   }
// }

resource virtualMachine_Windows 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: virtualMachine_Name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: virtualMachine_Size
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        name: '${virtualMachine_Name}_OsDisk_1'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
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
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
          enableHotpatching: false
        }
        enableVMAgentPlatformUpdates: false
      }
      secrets: []
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.outputs.networkInterface_ID
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

resource virtualMachine_NetworkWatcherExtension 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  parent: virtualMachine_Windows
  name: 'AzureNetworkWatcherExtension'
  location: location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.NetworkWatcher'
    type: 'NetworkWatcherAgentWindows'
    typeHandlerVersion: '1.4'
  }
}

resource virtualMachine_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_Windows
  name: 'installcustomscript'
  location: location
  tags: {
    displayName: 'install software for Windows virtualMachine'
  }
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        virtualMachine_ScriptFileUri
      ]
    }
    protectedSettings: {
      commandToExecute: commandToExecute
    }
  }
}

output virtualMachine_Name string = virtualMachine_Windows.name

output networkInterface_Name string = networkInterface.outputs.networkInterface_Name
output networkInterface_ID string = networkInterface.outputs.networkInterface_ID

output networkInterface_IPConfig0_Name string = networkInterface.outputs.networkInterface_IPConfig0_Name
output networkInterface_IPConfig0_ID string = networkInterface.outputs.networkInterface_IPConfig0_ID
output networkInterface_PrivateIPAddress string = networkInterface.outputs.networkInterface_PrivateIPAddress





