@description('Azure Datacenter location for all resources')
param location string = resourceGroup().location

param storageAccount_Name string = 'jamesgtestforpestuff'

param uniqueIdentifier string

module vnet '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: location
    virtualNetwork_Name: 'vnet_${uniqueIdentifier}'
  }
}

module StorageAccount '../../modules/Microsoft.Storage/StorageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    location: location
    storageAccount_Name: '${storageAccount_Name}${uniqueIdentifier}'
  }
}

module privateDNSZone '../../modules/Microsoft.Network/PrivateDNSZone.bicep' = {
  name: 'privateDNSZone'
  params: {
    privateDNSZone_Name: 'privatelink.blob.${environment().suffixes.storage}'
    virtualNetworkIDs: [vnet.outputs.virtualNetwork_ID]
  }
}

// module privateEndpoints '../../modules/Microsoft.Network/PrivateEndpoint.bicep' = [for i in range(1, 100): {
//   name: 'privateEndpoints_${i}'
//   params: {
//     groupID: 'blob'
//     location: location
//     privateDNSZone_Name: 'privatelink.blob.${environment().suffixes.storage}'
//     privateEndpoint_Name: '${storageAccount_Name}_pe_${i}'
//     privateEndpoint_SubnetID: vnet.outputs.privateEndpoint_SubnetID
//     privateLinkServiceId: StorageAccount.outputs.storageAccount_ID
//     virtualNetwork_IDs: [vnet.outputs.virtualNetwork_ID]
//   }
// } ]

module privateEndPointsnopdz '../../modules/Microsoft.Network/PrivateEndpointNoPDZ.bicep' = [for i in range(1, 100): {
  name: 'privateEndPointsnopdz_${i}'
  params: {
    location: location
    groupID: 'blob'
    privateDNSZone_Id: privateDNSZone.outputs.PrivateDNSZone_ID
    privateEndpoint_Name: '${storageAccount_Name}_pe_${i}'
    privateEndpoint_SubnetID: vnet.outputs.privateEndpoint_SubnetID
    privateLinkServiceId: StorageAccount.outputs.storageAccount_ID
  }
} ]
