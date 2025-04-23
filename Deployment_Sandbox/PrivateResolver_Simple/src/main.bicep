@description('Azure Datacenter location for the Hub and Spoke A resources')
var location = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@minLength(8)
@description('''Password for the admin account of the Virtual Machines.
Ensure the password meets typical Azure VM password requirements.
''')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param vmSize string = 'Standard_D2as_v4' // 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = true

var virtualMachine_ScriptFile = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/WinServ2025_ConfigScript.ps1'

param tagValues object = {
  Sandbox: 'PrivateResolver'
}

resource networkSecurityGroup_Generic 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'genericNSG'
  location: location
}

resource virtualNetwork_Hub 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'hub_VNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'General'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup_Generic.id
          }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'PRInboundEndpointSubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'PROutboundEndpointSubnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
        }
      }
    ]
  }
}


resource virtualNetwork_SpokeA 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'spokeA_VNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'General'
        properties: {
          addressPrefix: '10.1.0.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup_Generic.id
          }
        }
      }
    ]
  }
}

module peerings_Hub_to_Spokes_NoGateway '../../../modules/Microsoft.Network/VirtualNetworkPeeringsHub2SpokesNoGateway.bicep' = {
  name: 'peerings_Hub_to_Spokes_NoGateway'
  params: {
    virtualNetwork_Hub_Id: virtualNetwork_Hub.id
    virtualNetwork_Spoke_Ids: [
      virtualNetwork_SpokeA.id
    ]
  }
}

// Start of hub-DnsVM
var virtualMachine_Hub_Dns_Name = 'hub-dnsVM'
resource virtualMachine_Hub_Dns 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachine_Hub_Dns_Name
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
        name: '${virtualMachine_Hub_Dns_Name}_OsDisk_1'
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
      computerName: virtualMachine_Hub_Dns_Name
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
          id: virtualMachine_Hub_Dns_NIC.id
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
resource virtualMachine_Hub_Dns_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${virtualMachine_Hub_Dns_Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: '10.0.0.4'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: virtualNetwork_Hub.properties.subnets[0].id
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
resource virtualMachine_Hub_Dns_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_Hub_Dns
  name: 'installcustomscript'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [ virtualMachine_ScriptFile]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type DNS'
    }
  }
  tags: tagValues
}
// End of hub-DnsVM


// Start of spokeA-ClientVM
var virtualMachine_SpokeA_Client_Name = 'spokeA-clientVM'
resource virtualMachine_SpokeA_Client 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachine_SpokeA_Client_Name
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
        name: '${virtualMachine_SpokeA_Client_Name}_OsDisk_1'
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
      computerName: virtualMachine_SpokeA_Client_Name
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
          id: virtualMachine_SpokeA_Client_NIC.id
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
resource virtualMachine_SpokeA_Client_NIC 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: '${virtualMachine_SpokeA_Client_Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: '10.1.0.4'
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: virtualNetwork_SpokeA.properties.subnets[0].id
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
resource virtualMachine_SpokeA_Client_CustomScriptExtension 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: virtualMachine_SpokeA_Client
  name: 'installcustomscript'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.9'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [ virtualMachine_ScriptFile ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2025_ConfigScript.ps1 -Username ${virtualMachine_AdminUsername} -Type General'
    }
  }
  tags: tagValues
}
// End of spokeA-ClientVM

module bastion '../../../modules/Microsoft.Network/BastionEverything.bicep' = {
  name: 'AllBastionResources'
  params: {
    location: location
    peered_VirtualNetwork_Ids: [ 
      virtualNetwork_Hub.id
      virtualNetwork_SpokeA.id
    ] 
    bastion_name: 'Bastion'
    virtualNetwork_AddressPrefix: '10.200.0.0/24'
  }
}


module privateResolver_Hub '../../../modules/Microsoft.Network/DNSPrivateResolver.bicep' = {
  name: 'PrivateResolver_Hub'
  params: {
    location: location
    dnsPrivateResolver_Inbound_SubnetID: virtualNetwork_Hub.properties.subnets[2].id
    dnsPrivateResolver_Outbound_SubnetID: virtualNetwork_Hub.properties.subnets[3].id
    virtualNetwork_ID: virtualNetwork_Hub.id
  }
}

module privateResolver_Ruleset_Hub '../../../modules/Microsoft.Network/DNSPrivateResolverRuleSet.bicep' = {
  name: 'PrivateResolver_ForwardingRuleset_Hub'
  params: {
    location: location
    virtualNetwork_IDs: [ virtualNetwork_SpokeA.id ]
    outboundEndpoint_ID: privateResolver_Hub.outputs.dnsPrivateResolver_Outbound_Endpoint_ID
    domainName: 'contoso.com.'
    targetDNSServers: [
      {
        ipaddress: '8.8.8.8'
        port: 53
      }
    ]
  }
}
