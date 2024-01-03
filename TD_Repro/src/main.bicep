@description('Azure Datacenter location for the Hub and Server A resources')
param locationClient string = 'westeurope'

@description('''
Azure Datacenter location for the Server B resources.  
Use the same region as locationClient if you do not want to test multi-region
''')
param locationServer string = 'westeurope'

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Password for the Virtual Machine Admin User')
param virtualMachine_Size string = 'Standard_D2s_v3'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = true

@maxValue(1000)
@description('Number of Client Virtual Machines to be used as the source of the traffic')
param numberOfClientVMs int

@maxValue(1000)
@description('Number of Server Virtual Machines to be used as the destination of the traffic')
param numberOfServerVMs int

// @description('Set to true if you want to use an Azure Firewall between client and server.')
// param usingAzureFirewall bool = false

@description('''
Storage account name restrictions:
- Storage account names must be between 3 and 24 characters in length and may contain numbers and lowercase letters only.
- Your storage account name must be unique within Azure. No two storage accounts can have the same name.
''')
@minLength(3)
@maxLength(24)
param storageAccount_Name string = 'stortemp${uniqueString(resourceGroup().id)}'

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/Refactoring/scripts/'


module virtualNetwork_Client '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'clientVNet'
  params: {
    virtualNetwork_AddressPrefix: '10.100.0.0/16'
    location: locationClient
    virtualNetwork_Name: 'Client_VNet'

  }
}

module virtualNetwork_Server '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'serverVNet'
  params: {
    virtualNetwork_AddressPrefix: '10.101.0.0/16'
    location: locationServer
    virtualNetwork_Name: 'Server_VNet'
  }
}
module clientToServerPeering '../../modules/Microsoft.Network/VirtualNetworkPeering.bicep' = {
  name: 'clientToServerPeering'
  params: {
    virtualNetwork_Source_Name: virtualNetwork_Client.outputs.virtualNetwork_Name
    virtualNetwork_Destination_Name: virtualNetwork_Server.outputs.virtualNetwork_Name
  }
}

module clientVM_Linux '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = [ for i in range(0, numberOfClientVMs):  {
  name: 'clientVM${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationClient
    subnet_ID: virtualNetwork_Client.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'ClientVM${i}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    // Use the following for blob testing
    virtualMachine_ScriptFileName: 'conntestClientBlob.sh'
    commandToExecute: './conntestClientBlob.sh ${privateLink.outputs.internalLoadBalancer_FrontendIPAddress} ${storageAccount.outputs.storageAccount_Name} ${storageAccount.outputs.storageAccount_key0} ${storageAccountContainers.outputs.container_Names[0]} /tmp/captures'
    // virtualMachine_ScriptFileName: 'conntestClient.sh'
    // Use the following for Private Link testing
    // commandToExecute: './conntestClient.sh ${privateEndpoint_NIC.outputs.privateEndpoint_IPAddress} ${scenario_Name} ${storageAccount.outputs.storageAccount_Name} ${storageAccount.outputs.storageAccountFileShare_Name} ${storageAccount.outputs.storageAccount_key0}'
    // Use the following for Load Balancer testing
    // commandToExecute: './conntestClient.sh ${privateLink.outputs.internalLoadBalancer_FrontendIPAddress} ${scenario_Name} ${storageAccount.outputs.storageAccount_Name} ${storageAccount.outputs.storageAccountFileShare_Name} ${storageAccount.outputs.storageAccount_key0}'

  }
  dependsOn: [
    storageAccount
    client_StorageAccount_Blob_PrivateEndpoint
    ServerVM_Linux
  ]
} ]

module ServerVM_Linux '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = [ for i in range(0, numberOfServerVMs): {
  name: 'serverVM${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationServer
    subnet_ID: virtualNetwork_Server.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'ServerVM${i}'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    // virtualMachine_ScriptFileName: 'conntestServer.sh'
    // commandToExecute: './conntestServer.sh ${scenario_Name} ${storageAccount.outputs.storageAccount_Name} ${storageAccount.outputs.storageAccountFileShare_Name} ${storageAccount.outputs.storageAccount_key0}'
    virtualMachine_ScriptFileName: 'conntestServerBlob.sh'
    commandToExecute: './conntestServerBlob.sh  ${storageAccount.outputs.storageAccount_Name} ${storageAccount.outputs.storageAccount_key0} ${storageAccountContainers.outputs.container_Names[0]} /tmp/captures'
  }
  dependsOn: [
    client_StorageAccount_Blob_PrivateEndpoint
  ]
} ]

module pcapReviewVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'pcapReviewVM'
  params: {
    acceleratedNetworking: false
    location: locationClient
    subnet_ID: virtualNetwork_Client.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'pcapReviewVM'
    virtualMachine_Size: 'Standard_B2ms'
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'pcapreviewer.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File pcapreviewer.ps1 -Username ${virtualMachine_AdminUsername} -StorageAccountName ${storageAccount.outputs.storageAccount_Name} -StorageAccountKey ${storageAccount.outputs.storageAccount_key0} -ContainerName ${storageAccountContainers.outputs.container_Names[0]} -NeedsReviewContainerName ${storageAccountContainers.outputs.container_Names[1]} -IgnoreContainerName ${storageAccountContainers.outputs.container_Names[2]}'
  }
  dependsOn: [
    clientVM_Linux // We only want to start checking for pcaps after the client has been deployed and starts capturing
  ]
}


// module firewall '../../modules/Microsoft.Network/AzureFirewall.bicep' = if (usingAzureFirewall) {
//   name: 'azfw'
//   params: {
//     azureFirewall_ManagementSubnet_ID: virtualNetwork_Client.outputs.azureFirewallManagement_SubnetID
//     azureFirewall_Name: 'azfw'
//     azureFirewall_SKU: 'Basic'
//     azureFirewall_Subnet_ID: virtualNetwork_Client.outputs.azureFirewall_SubnetID
//     azureFirewallPolicy_Name: 'azfw_policy'
//     location: locationClient
//   }
// }

// module udrToAzFW_Hub '../../modules/Microsoft.Network/RouteTable.bicep' = if (usingAzureFirewall) {
//   name: 'udrToAzFW_Hub'
//   params: {
//     addressPrefixs: [virtualNetwork_Server.outputs.virtualNetwork_AddressPrefix]
//     nextHopType: 'VirtualAppliance'
//     routeTable_Name: virtualNetwork_Client.outputs.routeTable_Name
//     routeTableRoute_Name: 'toAzFW'
//     nextHopIpAddress: firewall.outputs.azureFirewall_PrivateIPAddress
//   }
// }

// module udrToAzFW_Server '../../modules/Microsoft.Network/RouteTable.bicep' = if (usingAzureFirewall) {
//   name: 'udrToAzFW_Server'
//   params: {
//     addressPrefixs: [virtualNetwork_Client.outputs.virtualNetwork_AddressPrefix]
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

module storageAccount '../../modules/Microsoft.Storage/StorageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    location: locationClient
    storageAccount_Name: storageAccount_Name
  }
}

module storageAccountContainers '../../modules/Microsoft.Storage/Container.bicep' = {
  name: 'storageAccountContainers'
  params: {
    container_Names: ['unfilteredcaptures', 'needsreview', 'ignore']
    storageAccount_BlobServices_Name: storageAccount.outputs.storageAccount_BlobServices_Name
    storageAccount_Name: storageAccount.outputs.storageAccount_Name
  }
}

module client_StorageAccount_Blob_PrivateEndpoint '../../modules/Microsoft.Network/PrivateEndpoint.bicep' = {
  name: 'client_StorageAccount_Blob_PrivateEndpoint'
  params: {
    fqdn: '${storageAccount_Name}.blob.${environment().suffixes.storage}'
    groupID: 'blob'
    location: locationClient
    privateDNSZone_Name: 'privatelink.blob.${environment().suffixes.storage}'
    privateEndpoint_Name: '${storageAccount_Name}_blob_pe'
    privateEndpoint_SubnetID: virtualNetwork_Client.outputs.privateEndpoint_SubnetID
    privateLinkServiceId: storageAccount.outputs.storageAccount_ID
    virtualNetwork_IDs: [
      virtualNetwork_Client.outputs.virtualNetwork_ID
      virtualNetwork_Server.outputs.virtualNetwork_ID
    ]  
  }
}

module privateLink '../../modules/Microsoft.Network/PrivateLink.bicep' = {
  name: 'privatelink'
  params: {
    acceleratedNetworking: acceleratedNetworking
    internalLoadBalancer_SubnetID: virtualNetwork_Server.outputs.general_SubnetID
    location: locationServer
    networkInterface_IPConfig_Names: [for i in range(0, numberOfServerVMs): ServerVM_Linux[i].outputs.networkInterface_IPConfig0_Name]
    networkInterface_Names: [for i in range(0, numberOfServerVMs): ServerVM_Linux[i].outputs.networkInterface_Name]
    networkInterface_SubnetID: virtualNetwork_Server.outputs.general_SubnetID
    privateEndpoint_SubnetID: virtualNetwork_Client.outputs.privateEndpoint_SubnetID
    privateLink_SubnetID: virtualNetwork_Server.outputs.privateLinkService_SubnetID
    tcpPort: 5001
    enableTcpReset: true
  }
}

module privateEndpoint_NIC '../../modules/Microsoft.Network/PrivateEndpointNetworkInterface.bicep' = {
  name: 'pe_NIC'
  params: {
    existing_PrivateEndpoint_NetworkInterface_Name: privateLink.outputs.privateEndpoint_NetworkInterface_Name
  }
}





