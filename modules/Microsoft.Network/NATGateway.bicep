param natGateway_Name string

param location string

param tagValues object = {}

resource natGateway_vip 'Microsoft.Network/publicIPAddresses@2022-09-01' = {
  name: '${natGateway_Name}_VIP'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    ipTags: []
  }
  tags: tagValues
}

resource NATGateway 'Microsoft.Network/natGateways@2024-05-01' = {
  name: natGateway_Name
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: natGateway_vip.id
      }
    ]
  }
  tags: tagValues
}


output natGateway_Id string = NATGateway.id
