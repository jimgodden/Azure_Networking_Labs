@description('''Azure Region that the resources will be deployed to.
Example: eastus, westus, centralus''')
param location string

@maxLength(15)
@description('Name of the Virtual Machine')
param virtualMachineScaleSet_Name string

@description('Number of Virtual Machines Instances to create. (This can be modified later)')
param capacity int = 1

@description('''Size of the Virtual Machine
Examples:
B2ms - 2 Core 8GB Ram - Cannot use Accelerated Networking
D2as_v5 2 Core 8GB Ram - Uses Accelerated Networking''')
param virtualMachineScaleSet_Size string

@description('Admin Username for the Virtual Machine')
param virtualMachineScaleSet_AdminUsername string

@description('Password for the Virtual Machine Admin User')
@secure()
param virtualMachineScaleSet_AdminPassword string

@description('Name of the Virtual Machines Network Interface')
param networkInterface_Name string = '${virtualMachineScaleSet_Name}_NetworkInterface'

@description('True enables Accelerated Networking and False disabled it.  Not all virtualMachine sizes support Accel Net')
param acceleratedNetworking bool

@description('The Resource ID of the subnet to which the Network Interface will be assigned.')
param subnet_ID string

@description('''Location of the file to be ran while the Virtual Machine is being created.  Ensure that the path ends with a /
Example: https://example.com/scripts/''')
param virtualMachineScaleSet_ScriptFileLocation string = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

@description('''Name of the file to be ran while the Virtual Machine is being created
Example: Ubuntu20_DNS_Config.sh''')
param virtualMachineScaleSet_ScriptFileName string
// param virtualMachineScaleSet_ScriptFileName string = 'Ubuntu20_WebServer_Config.sh'

param commandToExecute string

param tagValues object = {}

@description('Number of SNAT ports per instance. 0 = auto-allocate. For large pools (300+ VMs), consider setting explicitly or adding more frontend IPs.')
param allocatedOutboundPorts int = 0

@description('Joins the file path and the file name together')
var virtualMachineScaleSet_ScriptFileUri = '${virtualMachineScaleSet_ScriptFileLocation}${virtualMachineScaleSet_ScriptFileName}'

module publicLoadBalancer '../../Microsoft.Network/PublicLoadBalancer.bicep' = {
  name: 'publicLoadBalancer'
  params: {
    location: location
    publicLoadBalancer_Name: '${virtualMachineScaleSet_Name}_publicLoadBalancer'
    allocatedOutboundPorts: allocatedOutboundPorts
  }
}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2024-03-01' = {
  name: virtualMachineScaleSet_Name
  location: location
  tags: tagValues
  sku: {
    name: virtualMachineScaleSet_Size
    tier: 'Standard'
    capacity: capacity
  }
  properties: {
    singlePlacementGroup: false
    orchestrationMode: 'Flexible'
    upgradePolicy: {
      mode: 'Manual'
    }
    scaleInPolicy: {
      rules: [
        'Default'
      ]
      // forceDeletion: false
    }
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: virtualMachineScaleSet_Name
        adminUsername: virtualMachineScaleSet_AdminUsername
        adminPassword: virtualMachineScaleSet_AdminPassword
        linuxConfiguration: {
          disablePasswordAuthentication: false
          provisionVMAgent: true
          patchSettings: {
            patchMode: 'ImageDefault'
            // automaticByPlatformSettings: {
            //   rebootSetting: 'IfRequired'
            //   bypassPlatformSafetyChecksOnUserSchedule: false
            // }
            // assessmentMode: 'ImageDefault'
          }
        }
      }
      storageProfile: {
        osDisk: {
          osType: 'Linux'
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
          deleteOption: 'Delete'
          diskSizeGB: 30
        }
        imageReference: {
          publisher: 'canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }
        diskControllerType: 'SCSI'
      }
      networkProfile: {
        networkApiVersion: '2020-11-01'
        networkInterfaceConfigurations: [
          {
            name: networkInterface_Name
            properties: {
              primary: true
              enableAcceleratedNetworking: acceleratedNetworking
              disableTcpStateTracking: false
              enableIPForwarding: true
              auxiliaryMode: 'None'
              auxiliarySku: 'None'
              deleteOption: 'Delete'
              ipConfigurations: [
                {
                  name: '${networkInterface_Name}-defaultIpConfiguration'
                  properties: {
                    privateIPAddressVersion: 'IPv4'
                    subnet: {
                      id: subnet_ID
                    }
                    primary: true
                    // publicIPAddressConfiguration: {
                    //   name: 'publicIp-vnet-nic01'
                    //   properties: {
                    //     idleTimeoutInMinutes: 15
                    //     ipTags: []
                    //     publicIPAddressVersion: 'IPv4'
                    //   }
                    // }
                    applicationSecurityGroups: []
                    loadBalancerBackendAddressPools: [
                      {
                        id: publicLoadBalancer.outputs.publicLoadBalancer_BackendAddressPoolID
                      }
                    ]
                    applicationGatewayBackendAddressPools: []
                  }
                }
              ]
            }
          }
        ]
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
        }
      }
      extensionProfile: {
        extensions: [
          {
            name: 'CustomScript'
            properties: {
              publisher: 'Microsoft.Azure.Extensions'
              type: 'CustomScript'
              typeHandlerVersion: '2.1'
              autoUpgradeMinorVersion: true
              settings: {
                fileUris: [
                  virtualMachineScaleSet_ScriptFileUri
                ]
              }
              protectedSettings: {
                commandToExecute: commandToExecute
              }
            }
          }
        ]
      }
    }
    platformFaultDomainCount: 1
    automaticRepairsPolicy: {
      enabled: false
      gracePeriod: 'PT10M'
      repairAction: 'Replace'
    }
  }
}

output virtualMachineScaleSet_Name string = vmss.name
