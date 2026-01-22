@description('Azure Datacenter location for the source resources')
param location string = resourceGroup().location

// @description('Username for the admin account of the Virtual Machines')
// param virtualMachine_AdminUsername string

// @description('Password for the admin account of the Virtual Machines')
// @secure()
// param virtualMachine_AdminPassword string

// @description('Size of the Virtual Machines')
// param virtualMachine_Size string = 'Standard_D4as_v4' // 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

// @description('''True enables Accelerated Networking and False disabled it.  
// Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
// I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
// ''')
// param acceleratedNetworking bool = false

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'subnet1'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'DatabricksSubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: [
            {
              name: 'databricksDelegation'
              properties: {
                serviceName: 'Microsoft.Databricks/workspaces'
              }
            }
          ]
        }
      }
      {
        name: 'PrivateEndpointSubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
        }
      }
    ]
    enableDdosProtection: false
  }
}

// // Start of webVM
// var virtualMachine_WebVM_Name = 'webVM'
// resource virtualMachine_WebVM 'Microsoft.Compute/virtualMachines@2024-07-01' = {
//   name: virtualMachine_WebVM_Name
//   location: location
//   identity: {
//     type: 'SystemAssigned'
//   }
//   properties: {
//     hardwareProfile: {
//       vmSize: virtualMachine_Size
//     }
//     additionalCapabilities: {
//       hibernationEnabled: false
//     }
//     storageProfile: {
//       imageReference: {
//         publisher: 'MicrosoftWindowsServer'
//         offer: 'WindowsServer'
//         sku: '2025-datacenter-azure-edition'
//         version: 'latest'
//       }
//       osDisk: {
//         osType: 'Windows'
//         name: '${virtualMachine_WebVM_Name}_OsDisk_1'
//         createOption: 'FromImage'
//         caching: 'ReadWrite'
//         managedDisk: {
//           storageAccountType: 'Premium_LRS'
//         }
//         deleteOption: 'Delete'
//         diskSizeGB: 127
//       }
//       dataDisks: []
//       diskControllerType: 'SCSI'
//     }
//     osProfile: {
//       computerName: virtualMachine_WebVM_Name
//       adminUsername: virtualMachine_AdminUsername
//       adminPassword: virtualMachine_AdminPassword
//       windowsConfiguration: {
//         provisionVMAgent: true
//         enableAutomaticUpdates: true
//         patchSettings: {
//           patchMode: 'AutomaticByPlatform'
//           automaticByPlatformSettings: {
//             rebootSetting: 'IfRequired'
//           }
//           assessmentMode: 'ImageDefault'
//           enableHotpatching: true
//         }
//       }
//       secrets: []
//       allowExtensionOperations: true
//     }
//     securityProfile: {
//       uefiSettings: {
//         secureBootEnabled: true
//         vTpmEnabled: true
//       }
//       securityType: 'TrustedLaunch'
//     }
//     networkProfile: {
//       networkInterfaces: [
//         {
//           id: virtualMachine_WebVM_NIC.id
//           properties: {
//             deleteOption: 'Delete'
//           }
//         }
//       ]
//     }
//     diagnosticsProfile: {
//       bootDiagnostics: {
//         enabled: true
//       }
//     }
//   }
// }
// resource virtualMachine_WebVM_PublicIP 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
//   name: '${virtualMachine_WebVM_Name}-publicip'
//   location: location
//   sku: {
//     name: 'Standard'
//     tier: 'Regional'
//   }
//   properties: {
//     publicIPAllocationMethod: 'Static'
    
//   }
// }
// resource virtualMachine_WebVM_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
//   name: '${virtualMachine_WebVM_Name}-nic'
//   location: location
//   properties: {
//     ipConfigurations: [
//       {
//         name: 'ipconfig1'
//         properties: {
//           publicIPAddress: {
//             id: virtualMachine_WebVM_PublicIP.id
//           }
//           privateIPAllocationMethod: 'Dynamic'
//           subnet: {
//             id: virtualNetwork.properties.subnets[0].id
//           }
//           primary: true
//           privateIPAddressVersion: 'IPv4'
//         }
//       }
//     ]
//     enableAcceleratedNetworking: acceleratedNetworking
//   }
// }
// resource virtualMachine_WebVM_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
//   parent: virtualMachine_WebVM
//   name: 'installcustomscript'
//   location: location
//   properties: {
//     publisher: 'Microsoft.Compute'
//     type: 'CustomScriptExtension'
//     typeHandlerVersion: '1.9'
//     autoUpgradeMinorVersion: true
//     settings: {
//       fileUris: [ 
//         'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2025_ConfigScript.ps1'
//       ]
//     }
//     protectedSettings: {
//       commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type WebServer'
//     }
//   }
// }
// // End of webVM


// module bastionEverything '../../../modules/Microsoft.Network/BastionEverything.bicep' = {
//   name: 'bastion1'
//   params: {
//     location: location
//     bastion_name: 'bastion'
//     peered_VirtualNetwork_Ids: [
//       virtualNetwork.id
//     ]
//     virtualNetwork_AddressPrefix: '10.200.0.0/16'
//   }
// }

module vpn '../../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'vpn1'
  params: {
    location: location
    virtualNetworkGateway_Name: 'vpn'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork.properties.subnets[3].id
    virtualNetworkGateway_SKU: 'VpnGw1AZ'
    vpnGatewayGeneration: 'Generation1'
    virtualNetworkGateway_ASN: 65515
  }
}
