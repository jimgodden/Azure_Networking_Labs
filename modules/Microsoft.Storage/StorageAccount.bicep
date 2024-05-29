@description('Azure Datacenter that the resource is deployed to')
param location string

@description('''
Storage account name restrictions:
- Storage account names must be between 3 and 24 characters in length and may contain numbers and lowercase letters only.
- Your storage account name must be unique within Azure. No two storage accounts can have the same name.
''')
@minLength(3)
@maxLength(24)
param storageAccount_Name string

param tagValues object = {}

// Grabs the FQDN of the Blob but removes the extra that we don't need
// Original value https://{storageAccount_Name}.blob.core.windows.net/
// Output {storageAccount_Name}.blob.core.windows.net
var blobEndpoint = storageAccount.properties.primaryEndpoints.blob
var blobEndpointNoHTTPS = substring(blobEndpoint, 7, 8)
var blobFQDN = take(blobEndpointNoHTTPS, length(blobEndpointNoHTTPS) - 1)


// Grabs the FQDN of the Blob but removes the extra that we don't need
// Original value https://{storageAccount_Name}.blob.core.windows.net/
// Output {storageAccount_Name}.blob.core.windows.net
var fileEndpoint = storageAccount.properties.primaryEndpoints.file
var fileEndpointNoHTTPS = substring(fileEndpoint, 7, 8)
var fileFQDN = take(fileEndpointNoHTTPS, length(fileEndpointNoHTTPS) - 1)


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
  tags: tagValues
}

resource storageAccount_BlobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
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

output storageaccount_Blob_FQDN string = blobFQDN
output storageaccount_File_FQDN string = fileFQDN

output storageAccount_Name string = storageAccount.name
output storageAccount_ID string = storageAccount.id

output storageAccount_BlobServices_Name string = storageAccount_BlobServices.name

output storageAccountFileShare_Name string = storageAccount_File_FileShare.name

#disable-next-line outputs-should-not-contain-secrets // disabling this warning since this deployment is for testing only
output storageAccount_key0 string = storageAccount.listKeys().keys[0].value
