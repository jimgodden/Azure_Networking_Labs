param privateEndpoint_Objects array

@description('Resource location.')
param location string

param privateEndpoint_Names array

param privateEndpoint_SubnetIDs array

@description('The resource id of private link service.')
param resource_ID string

@description('The ID of the group obtained from the remote resource that this private endpoint should connect to.')
param groupID string

@description('Extracts the name of the resource from the Resource ID')
var resource_Name = last(split(resource_ID, '/'))


resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = [ for privateEndpoint_Object in privateEndpoint_Objects: {
  name: '${privateEndpoint_Object.Name}'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: '${privateEndpoint_Object.Name}_in_${privateEndpoint_Object.VirtualNetwork_Name}_to_${resource_Name}'
        properties: {
          privateLinkServiceId: resource_ID
          groupIds: [
            groupID
          ]
        }
      }
    ]
    manualPrivateLinkServiceConnections: []
    subnet: {
      id: privateEndpoint_Object.Subnet_ID
    }
    ipConfigurations: []
    customDnsConfigs: [
      {
        fqdn: privateEndpoint_Object.FQDN
      }
    ]
  }
} ]

module 
