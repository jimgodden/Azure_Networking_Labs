param location string

@description('Name of the Virtual Machine')
param virtualMachine_Name string

@description('Size of the virtualMachine')
param virtualMachine_Size string

@description('Admin Username for the Virtual Machine')
param virtualMachine_AdminUserName string

@description('Password for the Virtual Machine Admin User')
@secure()
param virtualMachine_AdminPassword string

@description('Name of the Virtual Machines Network Interface')
param networkInterface_Name string

@description('True enables Accelerated Networking and False disabled it.  Not all virtualMachine sizes support Accel Net')
param acceleratedNetworking bool

param subnet_ID string

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
      adminUsername: virtualMachine_AdminUserName
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
