param storageAccount_Name string

param storageAccount_BlobServices_Name string

param container_Names array

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01'  existing = {
  name: storageAccount_Name
}

resource storageAccount_BlobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' existing = {
  parent: storageAccount
  name: storageAccount_BlobServices_Name
}

resource storageAccount_Blob_Container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [ for container_Name in container_Names: {
  parent: storageAccount_BlobServices
  name: container_Name
} ]

output container_Names array = [ for i in range(0, length(container_Names)): storageAccount_Blob_Container[i].name ]
