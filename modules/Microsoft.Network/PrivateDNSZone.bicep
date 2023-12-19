param privateDNSZone_Name string

param registrationEnabled bool = false

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
    registrationEnabled: registrationEnabled
    virtualNetwork: {
      id: virtualNetworkID
    }
  }
} ]





















