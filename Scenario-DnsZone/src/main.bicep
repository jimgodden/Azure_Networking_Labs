@description('Name of the DNS Zone for public DNS resolution.')
param publicDNSZone_Name string

@description('Name of the TXT record to be modified.')
param txtRecord_Name string

@description('Array of values for the Text Record.')
param txtRecord_Values array

resource Record_TXT 'Microsoft.Network/dnsZones/TXT@2023-07-01-preview' = {
  name: '${publicDNSZone_Name}/${txtRecord_Name}'
  properties: {
    TXTRecords: [
      {
        value: txtRecord_Values
        // value: [
        //   'txtvers=1'
        //   'proto=https'
        //   'path=/acs/resources/configurations'
        // ]
      }
    ]
    TTL: 3600
  }
} 
