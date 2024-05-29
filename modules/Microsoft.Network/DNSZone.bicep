param dnsZone_Name string

param tagValues object = {}

resource DNSZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: dnsZone_Name
  location: 'global'
  tags: tagValues
}

resource DNSZoneARecord 'Microsoft.Network/dnsZones/A@2018-05-01' = {
  parent: DNSZone
  name: 'test'
  properties: {
   ARecords: [
    {
      ipv4Address: '10.255.255.254'
    }
   ]
    TTL: 10
  }
}


output dnsZone_NameServers array = DNSZone.properties.nameServers
