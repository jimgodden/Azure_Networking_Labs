param location string

param privateEndpoint_SubnetID string 

param privateDNSZoneLinkedVnetIDs array

resource filesharePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'fspe'
  location: location
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
      id: privateEndpoint_SubnetID
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

resource virtualNetworkLink_File 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = [ for privateDNSZoneLinkedVnetID in privateDNSZoneLinkedVnetIDs: {
  parent: privateDNSZone_StorageAccount_File
  name: '${filesharePrivateEndpoint.name}_to_${last(split(privateDNSZoneLinkedVnetID, '/'))}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: privateDNSZoneLinkedVnetID
    }
  }
}]
