@description('Azure Datacenter location for the Hub and Server A resources')
param locationClient string = 'westeurope'

@description('''
Azure Datacenter location for the Server B resources.  
Use the same region as locationClient if you do not want to test multi-region
''')
param locationServer string = 'westeurope'

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

param scenario_Name string

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


module virtualNetwork_Client '../../modules/Microsoft.Network/VirtualNetworkHub.bicep' = {
  name: 'clientVNet'
  params: {
    firstTwoOctetsOfVirtualNetworkPrefix: '10.100'
    location: locationClient
    virtualNetwork_Name: 'Client_VNet'
  }
}

module virtualNetwork_Server '../../modules/Microsoft.Network/VirtualNetworkSpoke.bicep' = {
  name: 'serverBVNet'
  params: {
    firstTwoOctetsOfVirtualNetworkPrefix: '10.101'
    location: locationServer
    virtualNetwork_Name: 'Server_VNet'
  }
}
module clientToServerBPeering '../../modules/Microsoft.Network/VirtualNetworkPeering.bicep' = {
  name: 'clientToServerBPeering'
  params: {
    virtualNetwork_Source_Name: virtualNetwork_Client.outputs.virtualNetwork_Name
    virtualNetwork_Destination_Name: virtualNetwork_Server.outputs.virtualNetwork_Name
  }
}

module clientVM_Linux '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = {
  name: 'clientvm'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationClient
    subnet_ID: virtualNetwork_Client.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_adminPassword
    virtualMachine_AdminUsername: virtualMachine_adminUsername
    virtualMachine_Name: 'clientVM-Linux'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'
    virtualMachine_ScriptFileName: 'conntestClient.sh'
    commandToExecute: './conntestClient.sh ${privateEndpoint_NIC.outputs.privateEndpoint_IPAddress} ${scenario_Name}'
    // virtualMachine_ScriptFileName: 'conntest'
    // commandToExecute: 'nohup ./conntest -c ${ilb.outputs.frontendIPAddress} -p 5001 &'
    // commandToExecute: 'nohup ./conntest -c ${privateEndpoint_NIC.outputs.privateEndpoint_IPAddress} -p 5001 &'
    // commandToExecute: 'nohup ./conntest -c ${privateLink.outputs.internalLoadBalancer_FrontendIPAddress} -p 5001 &'

  }
}

module ServerVM_Linux1 '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = {
  name: 'serverVM1-lin'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationServer
    subnet_ID: virtualNetwork_Server.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_adminPassword
    virtualMachine_AdminUsername: virtualMachine_adminUsername
    virtualMachine_Name: 'ServerVM1'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'
    virtualMachine_ScriptFileName: 'conntestServer.sh'
    // virtualMachine_ScriptFileName: 'conntest'
    commandToExecute: './conntestServer.sh ${scenario_Name}'
    // commandToExecute: 'nohup ./conntest -s -p 5001 &'
  }
  dependsOn: [
    mainfilesharePrivateEndpoints
  ]
}

// module ServerBVM_Linux2 '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = {
//   name: 'serverbVMlin2'
//   params: {
//     acceleratedNetworking: acceleratedNetworking
//     location: locationServer
//     subnet_ID: virtualNetwork_Server.outputs.general_SubnetID
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
//     location: locationClient
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

// module udrToAzFW_ServerB '../../modules/Microsoft.Network/RouteTable.bicep' = if (usingAzureFirewall) {
//   name: 'udrToAzFW_ServerB'
//   params: {
//     addressPrefix: '10.100.0.0/24'
//     nextHopType: 'VirtualAppliance'
//     routeTable_Name: virtualNetwork_Server.outputs.routeTable_Name
//     routeTableRoute_Name: 'toAzFW'
//     nextHopIpAddress: firewall.outputs.azureFirewall_PrivateIPAddress
//   }
// }

module clientBastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'clientBastion'
  params: {
    bastion_SubnetID: virtualNetwork_Client.outputs.bastion_SubnetID
    location: locationClient
  }
}

// module storageAccount '../../modules/Microsoft.Storage/StorageAccount.bicep' = {
//   name: 'storageAccount'
//   params: {
//     location: locationClient
//     privateDNSZoneLinkedVnetIDList: [virtualNetwork_Hub.outputs.virtualNetwork_ID, virtualNetwork_Server.outputs.virtualNetwork_ID]
//     privateDNSZoneLinkedVnetNamesList: [virtualNetwork_Hub.outputs.virtualNetwork_Name, virtualNetwork_Server.outputs.virtualNetwork_Name]
//     privateEndpoint_SubnetID: [virtualNetwork_Hub.outputs.privateEndpoint_SubnetID, virtualNetwork_Server.outputs.privateEndpoint_SubnetID]
//     privateEndpoint_VirtualNetwork_Name: [virtualNetwork_Hub.outputs.virtualNetwork_Name, virtualNetwork_Server.outputs.virtualNetwork_Name]
//     privateEndpoints_Blob_Name: 'blob_pe'
//     privateEndpoints_File_Name: 'fileshare_pe'
//     storageAccount_Name: storageAccount_Name
//   }
// }

// module ilb '../../modules/Microsoft.Network/InternalLoadBalancer.bicep' = {
  //   name: 'ilb'
  //   params: {
  //     internalLoadBalancer_SubnetID: virtualNetwork_Server.outputs.general_SubnetID
  //     location: locationServer
  //     networkInterface_IPConfig_Name: [ServerVM_Linux1.outputs.networkInterface_IPConfig0_Name, ServerBVM_Linux2.outputs.networkInterface_IPConfig0_Name ]
  //     networkInterface_Name: [ServerVM_Linux1.outputs.networkInterface_Name, ServerBVM_Linux2.outputs.networkInterface_Name]
  //     networkInterface_SubnetID: [virtualNetwork_Server.outputs.general_SubnetID, virtualNetwork_Server.outputs.general_SubnetID]
  //     tcpPort: 5001
  //     enableTcpReset: true
  //   }
  //   dependsOn: [
  //     clientBastion
  //   ]
  // }

module privateLink '../../modules/Microsoft.Network/PrivateLink.bicep' = {
  name: 'privatelink'
  params: {
    internalLoadBalancer_SubnetID: virtualNetwork_Server.outputs.general_SubnetID
    location: locationServer
    networkInterface_IPConfig_Name: ServerVM_Linux1.outputs.networkInterface_IPConfig0_Name
    networkInterface_Name: ServerVM_Linux1.outputs.networkInterface_Name
    networkInterface_SubnetID: virtualNetwork_Server.outputs.general_SubnetID
    privateEndpoint_SubnetID: virtualNetwork_Client.outputs.privateEndpoint_SubnetID
    privateLink_SubnetID: virtualNetwork_Server.outputs.privateLinkService_SubnetID
    tcpPort: 5001
  }
}

module privateEndpoint_NIC '../../modules/Microsoft.Network/PrivateEndpointNetworkInterface.bicep' = {
  name: 'pe_NIC'
  params: {
    existing_PrivateEndpoint_NetworkInterface_Name: privateLink.outputs.privateEndpoint_NetworkInterface_Name
  }
}

module mainfilesharePrivateEndpoints '../../modules/filesystemPE.bicep' = {
  name: 'mainfilesharePE'
  params: {
    fqdn: 'mainjamesgstorage.file.core.windows.net'
    privateDNSZone_Name: 'privatelink.file.core.windows.net'
    privateEndpoint_Name: 'blob_pe'
    privateLinkServiceId: '/subscriptions/a2c8e9b2-b8d3-4f38-8a72-642d0012c518/resourceGroups/Main/providers/Microsoft.Storage/storageAccounts/mainjamesgstorage'
    location: locationClient
    groupID: 'file'
    privateDNSZoneLinkedVnetIDs: [virtualNetwork_Client.outputs.virtualNetwork_ID, virtualNetwork_Server.outputs.virtualNetwork_ID]
    privateEndpoint_SubnetID: virtualNetwork_Client.outputs.privateEndpoint_SubnetID
  }
}

module mainblobsharePrivateEndpoints '../../modules/filesystemPE.bicep' = {
  name: 'mainblobPE'
  params: {
    fqdn: 'mainjamesgstorage.blob.core.windows.net'
    privateDNSZone_Name: 'privatelink.blob.core.windows.net'
    privateEndpoint_Name: 'blob_pe'
    privateLinkServiceId: '/subscriptions/a2c8e9b2-b8d3-4f38-8a72-642d0012c518/resourceGroups/Main/providers/Microsoft.Storage/storageAccounts/mainjamesgstorage'
    location: locationClient
    groupID: 'blob'
    privateDNSZoneLinkedVnetIDs: [virtualNetwork_Client.outputs.virtualNetwork_ID, virtualNetwork_Server.outputs.virtualNetwork_ID]
    privateEndpoint_SubnetID: virtualNetwork_Client.outputs.privateEndpoint_SubnetID
  }
}


