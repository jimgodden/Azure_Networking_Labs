@description('the location for resolver VNET and dns private resolver')
param location string

@description('Resource ID of the Virtual Network to which the DNS Private resolver\'s ruleset will be linked.')
param virtualNetwork_IDs array

@description('Resource ID of the Outbound Endpoint to be associated with the forwarding ruleset')
param outboundEndpoint_ID string

@description('Name of the forwarding ruleset.')
param dnsForwardingRuleSet_Name string = 'forwardingRule'

@description('the target domain name for the forwarding ruleset.  Must end with a dot')
param domainName string

@description('''the list of target DNS servers ip address and the port number for conditional forwarding
Format to be used:
{
  ipaddress: '10.0.0.1'
  port: 53
}
{
  ipaddress: '10.0.0.2'
  port: 53
}
''')
param targetDNSServers array

param tagValues object = {}

resource dnsForwardingRuleSet 'Microsoft.Network/dnsForwardingRulesets@2022-07-01' = {
  name: dnsForwardingRuleSet_Name
  location: location
  properties: {
    dnsResolverOutboundEndpoints: [
      {
        id: outboundEndpoint_ID
      }
    ]
  }
  tags: tagValues
}

resource resolverLink 'Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2022-07-01' = [ for virtualNetwork_ID in virtualNetwork_IDs : {
  parent: dnsForwardingRuleSet
  name: '${last(split(virtualNetwork_ID, '/'))}_link'
  properties: {
    virtualNetwork: {
      id: virtualNetwork_ID
    }
  }
} ]

resource fwRules 'Microsoft.Network/dnsForwardingRulesets/forwardingRules@2022-07-01' = {
  parent: dnsForwardingRuleSet
  name: '${join(split(domainName, '.'), '')}_ForwardingRule' // Removes the periods from the domain name.
  properties: {
    domainName: domainName
    targetDnsServers: targetDNSServers
  }
}
