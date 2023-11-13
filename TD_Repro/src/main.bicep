@description('Azure Datacenter location for the Hub and Spoke A resources')
param locationA string = 'westeurope'

@description('''
Azure Datacenter location for the Spoke B resources.  
Use the same region as locationA if you do not want to test multi-region
''')
param locationB string = 'westeurope'

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_adminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_adminPassword string

@description('Password for the Virtual Machine Admin User')
param virtualMachine_Size string = 'Standard_D2s_v3'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = true

// param usingAzureFirewall bool = true

// @description('''
// Storage account name restrictions:
// - Storage account names must be between 3 and 24 characters in length and may contain numbers and lowercase letters only.
// - Your storage account name must be unique within Azure. No two storage accounts can have the same name.
// ''')
// @minLength(3)
// @maxLength(24)
// param storageAccount_Name string

// param aaron bool = false


module virtualNetwork_Hub '../../modules/Microsoft.Network/VirtualNetworkHub.bicep' = {
  name: 'hubVNet'
  params: {
    firstTwoOctetsOfVirtualNetworkPrefix: '10.100'
    location: locationA
    networkSecurityGroup_Default_Name: 'nsg_hub'
    routeTable_Name: 'rt_hub'
    virtualNetwork_Name: 'vnet_hub'
  }
}

module virtualNetwork_Spoke_B '../../modules/Microsoft.Network/VirtualNetworkSpoke.bicep' = {
  name: 'spokeBVNet'
  params: {
    firstTwoOctetsOfVirtualNetworkPrefix: '10.101'
    location: locationB
    networkSecurityGroup_Default_Name: 'nsg_SpokeB'
    routeTable_Name: 'rt_SpokeB'
    virtualNetwork_Name: 'VNet_SpokeB'
  }
}
module hubToSpokeBPeering '../../modules/Microsoft.Network/VirtualNetworkPeering.bicep' = {
  name: 'hubToSpokeBPeering'
  params: {
    virtualNetwork_Source_Name: virtualNetwork_Hub.outputs.virtualNetwork_Name
    virtualNetwork_Destination_Name: virtualNetwork_Spoke_B.outputs.virtualNetwork_Name
  }
}

module hubVM_Linux '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = {
  name: 'hubvm'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationA
    subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_adminPassword
    virtualMachine_AdminUsername: virtualMachine_adminUsername
    virtualMachine_Name: 'hubVM-Linux'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'
    commandToExecute: 'conntestClient.sh ${privateEndpoint_NIC.outputs.privateEndpoint_IPAddress} privateLink'
    // virtualMachine_ScriptFileName: 'conntest'
    // commandToExecute: 'nohup ./conntest -c ${ilb.outputs.frontendIPAddress} -p 5001 &'
    // commandToExecute: 'nohup ./conntest -c ${privateEndpoint_NIC.outputs.privateEndpoint_IPAddress} -p 5001 &'
    // commandToExecute: 'nohup ./conntest -c ${privateLink.outputs.internalLoadBalancer_FrontendIPAddress} -p 5001 &'

  }
}

module SpokeBVM_Linux1 '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = {
  name: 'spokebVMlin1'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationB
    subnet_ID: virtualNetwork_Spoke_B.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_adminPassword
    virtualMachine_AdminUsername: virtualMachine_adminUsername
    virtualMachine_Name: 'destVM1'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'
    virtualMachine_ScriptFileName: 'conntest'
    commandToExecute: 'conntestServer.sh privateLink'
    // commandToExecute: 'nohup ./conntest -s -p 5001 &'
  }
}

// module SpokeBVM_Linux2 '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = {
//   name: 'spokebVMlin2'
//   params: {
//     acceleratedNetworking: acceleratedNetworking
//     location: locationB
//     subnet_ID: virtualNetwork_Spoke_B.outputs.general_SubnetID
//     virtualMachine_AdminPassword: virtualMachine_adminPassword
//     virtualMachine_AdminUsername: virtualMachine_adminUsername
//     virtualMachine_Name: 'destvm2'
//     virtualMachine_Size: virtualMachine_Size
//     virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'
//     virtualMachine_ScriptFileName: 'conntest'
//     commandToExecute: 'nohup ./conntest -s -p 5001 &'
//   }
// }



// module firewall '../../modules/Microsoft.Network/AzureFirewall.bicep' = if (usingAzureFirewall) {
//   name: 'azfw'
//   params: {
//     azureFirewall_ManagementSubnet_ID: virtualNetwork_Hub.outputs.azureFirewallManagement_SubnetID
//     azureFirewall_Name: 'azfw'
//     azureFirewall_SKU: 'Basic'
//     azureFirewall_Subnet_ID: virtualNetwork_Hub.outputs.azureFirewall_SubnetID
//     azureFirewallPolicy_Name: 'azfw_policy'
//     location: locationA
//   }
// }

// module udrToAzFW_Hub '../../modules/Microsoft.Network/RouteTable.bicep' = if (usingAzureFirewall) {
//   name: 'udrToAzFW_Hub'
//   params: {
//     addressPrefix: '10.101.0.0/24'
//     nextHopType: 'VirtualAppliance'
//     routeTable_Name: virtualNetwork_Hub.outputs.routeTable_Name
//     routeTableRoute_Name: 'toAzFW'
//     nextHopIpAddress: firewall.outputs.azureFirewall_PrivateIPAddress
//   }
// }

// module udrToAzFW_SpokeB '../../modules/Microsoft.Network/RouteTable.bicep' = if (usingAzureFirewall) {
//   name: 'udrToAzFW_SpokeB'
//   params: {
//     addressPrefix: '10.100.0.0/24'
//     nextHopType: 'VirtualAppliance'
//     routeTable_Name: virtualNetwork_Spoke_B.outputs.routeTable_Name
//     routeTableRoute_Name: 'toAzFW'
//     nextHopIpAddress: firewall.outputs.azureFirewall_PrivateIPAddress
//   }
// }

module hubBastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'hubBastion'
  params: {
    bastion_SubnetID: virtualNetwork_Hub.outputs.bastion_SubnetID
    location: locationA
  }
}

// module storageAccount '../../modules/Microsoft.Storage/StorageAccount.bicep' = {
//   name: 'storageAccount'
//   params: {
//     location: locationA
//     privateDNSZoneLinkedVnetIDList: [virtualNetwork_Hub.outputs.virtualNetwork_ID, virtualNetwork_Spoke_B.outputs.virtualNetwork_ID]
//     privateDNSZoneLinkedVnetNamesList: [virtualNetwork_Hub.outputs.virtualNetwork_Name, virtualNetwork_Spoke_B.outputs.virtualNetwork_Name]
//     privateEndpoint_SubnetID: [virtualNetwork_Hub.outputs.privateEndpoint_SubnetID, virtualNetwork_Spoke_B.outputs.privateEndpoint_SubnetID]
//     privateEndpoint_VirtualNetwork_Name: [virtualNetwork_Hub.outputs.virtualNetwork_Name, virtualNetwork_Spoke_B.outputs.virtualNetwork_Name]
//     privateEndpoints_Blob_Name: 'blob_pe'
//     privateEndpoints_File_Name: 'fileshare_pe'
//     storageAccount_Name: storageAccount_Name
//   }
// }

// module ilb '../../modules/Microsoft.Network/InternalLoadBalancer.bicep' = {
  //   name: 'ilb'
  //   params: {
  //     internalLoadBalancer_SubnetID: virtualNetwork_Spoke_B.outputs.general_SubnetID
  //     location: locationB
  //     networkInterface_IPConfig_Name: [SpokeBVM_Linux1.outputs.networkInterface_IPConfig0_Name, SpokeBVM_Linux2.outputs.networkInterface_IPConfig0_Name ]
  //     networkInterface_Name: [SpokeBVM_Linux1.outputs.networkInterface_Name, SpokeBVM_Linux2.outputs.networkInterface_Name]
  //     networkInterface_SubnetID: [virtualNetwork_Spoke_B.outputs.general_SubnetID, virtualNetwork_Spoke_B.outputs.general_SubnetID]
  //     tcpPort: 5001
  //     enableTcpReset: true
  //   }
  //   dependsOn: [
  //     hubBastion
  //   ]
  // }

module privateLink '../../modules/Microsoft.Network/PrivateLink.bicep' = {
  name: 'pl'
  params: {
    internalLoadBalancer_SubnetID: virtualNetwork_Spoke_B.outputs.general_SubnetID
    location: locationB
    networkInterface_IPConfig_Name: SpokeBVM_Linux1.outputs.networkInterface_IPConfig0_Name
    networkInterface_Name: SpokeBVM_Linux1.outputs.networkInterface_Name
    networkInterface_SubnetID: virtualNetwork_Spoke_B.outputs.general_SubnetID
    privateEndpoint_SubnetID: virtualNetwork_Hub.outputs.privateEndpoint_SubnetID
    privateLink_SubnetID: virtualNetwork_Spoke_B.outputs.privateLinkService_SubnetID
    tcpPort: 5001
  }
}

module privateEndpoint_NIC '../../modules/Microsoft.Network/PrivateEndpointNetworkInterface.bicep' = {
  name: 'pe_NIC'
  params: {
    existing_PrivateEndpoint_NetworkInterface_Name: privateLink.outputs.privateEndpoint_NetworkInterface_Name
  }
}

resource filesharePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'fspe'
  location: locationA
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'pelocA'
        properties: {
          privateLinkServiceId: '/subscriptions/a2c8e9b2-b8d3-4f38-8a72-642d0012c518/resourceGroups/Main/providers/Microsoft.Storage/storageAccounts/mainjamesgstorage'
          groupIds: [
            'file'
          ]
        }
      }
    ]
    manualPrivateLinkServiceConnections: []
    subnet: {
      id: virtualNetwork_Hub.outputs.privateEndpoint_SubnetID
    }
    ipConfigurations: []
    customDnsConfigs: [
      {
        fqdn: 'mainjamesgstorage.file.core.windows.net'
      }
    ]
  }
}

resource privateDNSZone_StorageAccount_File 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.core.windows.net'
  location: 'global'
}

resource privateDNSZone_StorageAccount_File_Group 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = {
  parent: filesharePrivateEndpoint
  name: 'fileZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'default'
        properties: {
           privateDnsZoneId: privateDNSZone_StorageAccount_File.id
        }
      }
    ]
  }
}

resource virtualNetworkLink_File_Hub 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  parent: privateDNSZone_StorageAccount_File
  name: '${filesharePrivateEndpoint.name}_to_hubvnet'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork_Hub.outputs.virtualNetwork_ID
    }
  }
}

resource virtualNetworkLink_File_Spoke 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  parent: privateDNSZone_StorageAccount_File
  name: '${filesharePrivateEndpoint.name}_to_spokevnet'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork_Spoke_B.outputs.virtualNetwork_ID
    }
  }
}
