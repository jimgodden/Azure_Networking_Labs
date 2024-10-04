@description('Azure Datacenter location for the source resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param vmSize string // = 'Standard_D2as_v4' // 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = false

param tagValues object = {}

var virtualMachine_Name = 'winVM'

module virtualNetwork '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    virtualNetwork_Name: 'vnet'
  }
}


module networkInterface '../../Modules/Microsoft.Network/NetworkInterface.bicep' = {
  name: 'nic'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    networkInterface_Name: '${virtualMachine_Name}_nic'
    subnet_ID: virtualNetwork.outputs.general_SubnetID
    tagValues: tagValues
  }
}

resource virtualMachine_Windows 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: virtualMachine_Name
  location: location
  // identity: {
  //   type: 'SystemAssigned'
  // }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
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
      // dataDisks: []
      // diskControllerType: 'SCSI'
    }
    osProfile: {
      computerName: virtualMachine_Name
      adminUsername: virtualMachine_AdminUsername
      adminPassword: virtualMachine_AdminPassword
      // windowsConfiguration: {
      //   provisionVMAgent: true
      //   enableAutomaticUpdates: true
      //   patchSettings: {
      //     patchMode: 'AutomaticByOS'
      //     assessmentMode: 'ImageDefault'
      //     enableHotpatching: false
      //   }
      //   // enableVMAgentPlatformUpdates: false
      // }
      // secrets: []
      // allowExtensionOperations: true
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
    // diagnosticsProfile: {
    //   bootDiagnostics: {
    //     enabled: true
    //   }
    // }
  }
  tags: tagValues
}

resource virtualMachine_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_Windows
  name: 'installcustomscript'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/TCPConnectionTest.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File TCPConnectionTest.ps1 -IPAddress 8.8.8.8 -TCPPort 53'
    }
  }
  tags: tagValues
}

module bastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_name: 'hub_bastion'
    bastion_SubnetID: virtualNetwork.outputs.bastion_SubnetID
    location: location
  }
}
