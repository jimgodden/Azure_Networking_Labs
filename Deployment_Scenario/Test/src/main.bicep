@description('Azure Datacenter location for the source resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param virtualMachine_Size string = 'Standard_D4as_v4' // 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = false

module virtualNetwork_Hub '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet-hub'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    virtualNetwork_Name: 'vnet-hub'
  }
}

// Start of webVM
var virtualMachine_WebVM_Name = 'webVM'
resource virtualMachine_WebVM 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachine_WebVM_Name
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
        name: '${virtualMachine_WebVM_Name}_OsDisk_1'
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
      computerName: virtualMachine_WebVM_Name
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
          id: virtualMachine_WebVM_NIC.id
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
resource virtualMachine_WebVM_PublicIP 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: '${virtualMachine_WebVM_Name}-publicip'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    
  }
}
resource virtualMachine_WebVM_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${virtualMachine_WebVM_Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          publicIPAddress: {
            id: virtualMachine_WebVM_PublicIP.id
          }
          privateIPAllocationMethod: 'Dynamic'
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
}
resource virtualMachine_WebVM_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_WebVM
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
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type WebServer'
    }
  }
}
// End of webVM


// module virtualMachine_Client1 '../../../modules/Microsoft.Compute/VirtualMachine/Windows/Server2025_General.bicep' = {
//   name: 'vm-client1'
//   params: {
//     location: location
//     acceleratedNetworking: acceleratedNetworking
//     subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
//     virtualMachine_AdminPassword: virtualMachine_AdminPassword
//     virtualMachine_AdminUsername: virtualMachine_AdminUsername
//     virtualMachine_Name: 'vm-client1'
//     vmSize: 'Standard_E2ds_v5'
//   }
// }

// module virtualMachine_Client2 '../../../modules/Microsoft.Compute/VirtualMachine/Windows/Server2025_General.bicep' = {
//   name: 'vm-client2'
//   params: {
//     location: location
//     acceleratedNetworking: acceleratedNetworking
//     subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
//     virtualMachine_AdminPassword: virtualMachine_AdminPassword
//     virtualMachine_AdminUsername: virtualMachine_AdminUsername
//     virtualMachine_Name: 'E4'
//     vmSize: 'Standard_E2ds_v4'
//   }
// }

// module virtualMachine_Client3 '../../../modules/Microsoft.Compute/VirtualMachine/Windows/Server2025_General.bicep' = {
//   name: 'vm-client3'
//   params: {
//     location: location
//     acceleratedNetworking: acceleratedNetworking
//     subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
//     virtualMachine_AdminPassword: virtualMachine_AdminPassword
//     virtualMachine_AdminUsername: virtualMachine_AdminUsername
//     virtualMachine_Name: 'D5'
//     vmSize: 'Standard_D2s_v5'
//   }
// }

module bastion '../../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    location: location
    bastion_SubnetID: virtualNetwork_Hub.outputs.bastion_SubnetID
    bastion_name: 'bastion'
  }
}
