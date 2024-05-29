@description('the location for resolver VNET and dns private resolver - Azure DNS Private Resolver available in specific region, refer the documenation to select the supported region for this deployment. For more information https://docs.microsoft.com/azure/dns/dns-private-resolver-overview#regional-availability')
param location string

@description('Resource ID of the Virtual Network to which the DNS Private resolver will be added.')
param virtualNetwork_ID string

// @description('Extracts the name of the Virtual Network out of the Resource ID.')
// var virtualNetwork_Name = last(split(virtualNetwork_ID, '/'))

@description('Resource ID of the Subnet to which the DNS Private resolver Inbound Endpoint will be added.')
param dnsPrivateResolver_Inbound_SubnetID string

@description('Resource ID of the Subnet to which the DNS Private resolver Outbound Endpoint will be added.')
param dnsPrivateResolver_Outbound_SubnetID string

@description('name of the dns private resolver')
param dnsPrivateResolver_Name string = 'dnsResolver'

@description('name that will be used for the private resolver inbound endpoint')
param inboundEndpoint_Name string = 'endpoint-inbound'

@description('name that will be used for the private resolver outbound endpoint')
param outboundEndpoint_Name string = 'endpoint-outbound'

param tagValues object = {}

resource dnsPrivateResolver 'Microsoft.Network/dnsResolvers@2022-07-01' = {
  name: dnsPrivateResolver_Name
  location: location
  properties: {
    virtualNetwork: {
      id: virtualNetwork_ID
    }
  }
  tags: tagValues
}

resource inboundEndpoint 'Microsoft.Network/dnsResolvers/inboundEndpoints@2022-07-01' = {
  parent: dnsPrivateResolver
  name: inboundEndpoint_Name
  location: location
  properties: {
    ipConfigurations: [
      {
        privateIpAllocationMethod: 'Dynamic'
        subnet: {
          id: dnsPrivateResolver_Inbound_SubnetID
        }
      }
    ]
  }
  tags: tagValues
}

resource outboundEndpoint 'Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01' = {
  parent: dnsPrivateResolver
  name: outboundEndpoint_Name
  location: location
  properties: {
    subnet: {
      id: dnsPrivateResolver_Outbound_SubnetID
    }
  }
  tags: tagValues
}

output dnsPrivateResolver_Outbound_Endpoint_ID string = outboundEndpoint.id
output privateDNSResolver_Inbound_Endpoint_IPAddress string = inboundEndpoint.properties.ipConfigurations[0].privateIpAddress
