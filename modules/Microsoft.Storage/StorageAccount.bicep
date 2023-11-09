@description('Azure Datacenter that the resource is deployed to')
param location string

@description('Name of the Virtual Network that the Private Endpoint will be deployed to.')
param privateEndpoint_VirtualNetwork_Name array

param privateDNSZoneLinkedVnetNamesList array

param privateDNSZoneLinkedVnetIDList array

param privateEndpoint_SubnetID array

@description('''
Storage account name restrictions:
- Storage account names must be between 3 and 24 characters in length and may contain numbers and lowercase letters only.
- Your storage account name must be unique within Azure. No two storage accounts can have the same name.
''')
@minLength(3)
@maxLength(24)
param storageAccount_Name string

param usingBlobPrivateEndpoints bool = true
param usingFilePrivateEndpoints bool = true

param privateEndpoints_Blob_Name string
param privateEndpoints_File_Name string



// Grabs the FQDN of the Blob but removes the extra that we don't need
// Original value https://{storageAccount_Name}.blob.core.windows.net/
// Output {storageAccount_Name}.blob.core.windows.net
var blobEndpoint = storageAccount.properties.primaryEndpoints.blob
var blobEndpointNoHTTPS = substring(blobEndpoint, 7, 8)
var blobFQDN = take(blobEndpointNoHTTPS, length(blobEndpointNoHTTPS) - 1)


var privateDNSZone_Blob_Name = 'privatelink.blob.core.windows.net'


// Grabs the FQDN of the Blob but removes the extra that we don't need
// Original value https://{storageAccount_Name}.blob.core.windows.net/
// Output {storageAccount_Name}.blob.core.windows.net
var fileEndpoint = storageAccount.properties.primaryEndpoints.file
var fileEndpointNoHTTPS = substring(fileEndpoint, 7, 8)
var fileFQDN = take(fileEndpointNoHTTPS, length(fileEndpointNoHTTPS) - 1)

var privateDNSZone_File_Name = 'privatelink.file.core.windows.net'



resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccount_Name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: false
    publicNetworkAccess: 'Disabled'
    allowCrossTenantReplication: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Deny'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource storageAccount_Blob 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    changeFeed: {
      enabled: false
    }
    restorePolicy: {
      enabled: false
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      allowPermanentDelete: false
      enabled: true
      days: 7
    }
    isVersioningEnabled: false
  }
}

resource privateEndpoints_Blob 'Microsoft.Network/privateEndpoints@2023-04-01' =  [ for i in range(0, length(privateEndpoint_SubnetID)): if (usingBlobPrivateEndpoints)  {
  name: '${privateEndpoints_Blob_Name}${i}'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: '${privateEndpoints_Blob_Name}_in_${privateEndpoint_VirtualNetwork_Name}_to_${storageAccount_Name}'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    manualPrivateLinkServiceConnections: []
    subnet: {
      id: privateEndpoint_SubnetID[i]
    }
    ipConfigurations: []
    customDnsConfigs: [
      {
        fqdn: blobFQDN
      }
    ]
  }
} ]



resource privateDNSZone_StorageAccount_Blob 'Microsoft.Network/privateDnsZones@2018-09-01' = if (usingBlobPrivateEndpoints) {
  name: privateDNSZone_Blob_Name
  location: 'global'
}

resource privateDNSZone_StorageAccount_Blob_Group 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = [ for i in range(0, length(privateEndpoint_SubnetID)):  {
  parent: privateEndpoints_Blob[i]
  name: 'blobZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'default'
        properties: {
           privateDnsZoneId: privateDNSZone_StorageAccount_Blob.id
        }
      }
    ]
  }
} ]

resource virtualNetworkLink_Blob 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = [ for i in range(0, length(privateDNSZoneLinkedVnetIDList)): if (usingBlobPrivateEndpoints) {
  parent: privateDNSZone_StorageAccount_Blob
  name: '${privateDNSZone_Blob_Name}_to_${privateDNSZoneLinkedVnetNamesList[i]}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: privateDNSZoneLinkedVnetIDList[i]
    }
  }
}]

resource storageAccount_File 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource storageAccount_File_FileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: storageAccount_File
  name: 'defaultfileshare'
  properties: {
    accessTier: 'Hot'
    shareQuota: 1024
  }
}

resource privateEndpoints_File 'Microsoft.Network/privateEndpoints@2023-05-01' = [ for i in range(0, length(privateEndpoint_SubnetID)):  if (usingFilePrivateEndpoints) {
  name: '${privateEndpoints_File_Name}${i}'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: '${privateEndpoints_File_Name}_in_${privateEndpoint_VirtualNetwork_Name}_to_${storageAccount_Name}'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
    manualPrivateLinkServiceConnections: []
    subnet: {
      id: privateEndpoint_SubnetID[i]
    }
    ipConfigurations: []
    customDnsConfigs: [
      {
        fqdn: fileFQDN
      }
    ]
  }
} ]

resource privateDNSZone_StorageAccount_File 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDNSZone_File_Name
  location: 'global'
}

resource privateDNSZone_StorageAccount_File_Group 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = [ for i in range(0, length(privateEndpoint_SubnetID)):  {
  parent: privateEndpoints_File[i]
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
} ]

resource virtualNetworkLink_File 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = [ for i in range(0, length(privateDNSZoneLinkedVnetIDList)): if (usingFilePrivateEndpoints) {
  parent: privateDNSZone_StorageAccount_File
  name: '${privateDNSZone_File_Name}_to_${privateDNSZoneLinkedVnetNamesList[i]}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: privateDNSZoneLinkedVnetIDList[i]
    }
  }
}]


// output storageAccount_Blob_PrivateEndpoint_IPAddress array = privateEndpoints_Blob.properties.ipConfigurations[0].properties.privateIPAddress
// output storageAccount_File_PrivateEndpoint_IPAddress array = privateEndpoints_File.properties.ipConfigurations[0].properties.privateIPAddress

output storageaccount_Blob_FQDN string = blobFQDN
output storageaccount_File_FQDN string = fileFQDN
