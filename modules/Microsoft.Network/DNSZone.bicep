param dnsZone_Name string

resource DNSZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: dnsZone_Name
  location: 'global'
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




















