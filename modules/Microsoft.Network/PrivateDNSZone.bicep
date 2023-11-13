param privateDNSZone_Name string

param virtualNetworkIDs array

resource privateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDNSZone_Name
  location: 'global'
}

resource virtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for virtualNetworkID in virtualNetworkIDs:  {
  parent: privateDNSZone
  name: last(split(virtualNetworkID, '/'))
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkID
    }
  }
} ]

