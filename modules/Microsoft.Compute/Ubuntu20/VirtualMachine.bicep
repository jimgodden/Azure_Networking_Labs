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

@description('True enables Accelerated Networking and False disabled it.  Not all virtualMachine sizes support Accel Net')
param acceleratedNetworking bool

@description('The Resource ID of the subnet to which the Network Interface will be assigned.')
param subnet_ID string

@description('''Location of the file to be ran while the Virtual Machine is being created.  Ensure that the path ends with a /
Example: https://example.com/scripts/''')
param virtualMachine_ScriptFileLocation string = 'https://github.com/jimgodden/Azure_Networking_Labs/tree/main/scripts/'

@description('''Name of the file to be ran while the Virtual Machine is being created
Example: InitScript.ps1''')
param virtualMachine_ScriptFileName string = 'Ubuntu20_DNS_Config.sh'
// param virtualMachine_ScriptFileName string = 'Ubuntu20_WebServer_Config.sh'

param commandToExecute string = 'Ubuntu20_DNS_Config.sh'

@description('Joins the file path and the file name together')
var virtualMachine_ScriptFileUri = '${virtualMachine_ScriptFileLocation}${virtualMachine_ScriptFileName}'

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-09-01' = {
  name: networkInterface_Name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        type: 'Microsoft.Network/networkInterfaces/ipConfigurations'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet_ID
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
    enableIPForwarding: false
    disableTcpStateTracking: false
    nicType: 'Standard'
  }
}

resource virtualMachine_Linux 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: virtualMachine_Name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: virtualMachine_Size
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: '0001-com-ubuntu-server-focal'
        sku: '20_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        osType: 'Linux'
        name: '${virtualMachine_Name}_OsDisk_1'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        deleteOption: 'Delete'
      }
      dataDisks: []
    }
    osProfile: {
      computerName: virtualMachine_Name
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
          id: networkInterface.id
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
  parent: virtualMachine_Linux
  name: 'AzureNetworkWatcherExtension'
  location: location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.NetworkWatcher'
    type: 'NetworkWatcherAgentLinux'
    typeHandlerVersion: '1.4'
  }
}

resource vm_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_Linux
  name: 'installcustomscript'
  location: location
  tags: {
    displayName: 'install software for Linux VM'
  }
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
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

output networkInterface_Name string = networkInterface.name
output networkInterface_IPConfig0_Name string = networkInterface.properties.ipConfigurations[0].name
