param location string

@description('Name of the Virtual Machine')
param vm_Name string // = 'testvm${vHub_Iteration}'

@description('Admin Username for the Virtual Machine')
param vm_AdminUserName string

@description('Password for the Virtual Machine Admin User')
@secure()
param vm_AdminPassword string

@description('Name of the Virtual Machines Network Interface')
param nic_Name string // = '${vm_Name}_nic1'

param subnetID string

param vm_ScriptFileUri string = 'https://mainjamesgstorage.blob.core.windows.net/scripts/InitScript.ps1'


resource nic 'Microsoft.Network/networkInterfaces@2022-09-01' = {
  name: nic_Name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        type: 'Microsoft.Network/networkInterfaces/ipConfigurations'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetID
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: false
    enableIPForwarding: false
    disableTcpStateTracking: false
    nicType: 'Standard'
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: vm_Name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2ms'
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
        name: '${vm_Name}_OsDisk_1'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
          // id: resourceId('Microsoft.Compute/disks', '${vm_Name}_OsDisk_1')
        }
        deleteOption: 'Delete'
        diskSizeGB: 127
      }
      dataDisks: []
      diskControllerType: 'SCSI'
    }
    osProfile: {
      computerName: vm_Name
      adminUsername: vm_AdminUserName
      adminPassword: vm_AdminPassword
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
}

resource vm_NetworkWatcherExtension 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  parent: vm
  name: 'AzureNetworkWatcherExtension'
  location: location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.NetworkWatcher'
    type: 'NetworkWatcherAgentWindows'
    typeHandlerVersion: '1.4'
  }
}

resource vm_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: vm
  name: 'installcustomscript'
  location: location
  tags: {
    displayName: 'install software for Windows VM'
  }
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        vm_ScriptFileUri
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File InitScript.ps1'
    }
  }
}
