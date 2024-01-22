@description('Name of the Private DNS Zone that the record will be created in.')
param PrivateDNSZone_Name string

@description('Name of the A record.')
param ARecord_name string

@description('IPv4 Address of the A record.')
param ipv4Address string

resource PrivateDNSZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: PrivateDNSZone_Name
}

resource ARecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: PrivateDNSZone
  name: ARecord_name
  properties: {
    aRecords: [
      {
        ipv4Address: ipv4Address
      }
    ]
  }
}
