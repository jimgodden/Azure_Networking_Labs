param networkSecurityGroup_Name string

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-06-01'  existing = {
  name: networkSecurityGroup_Name
}

resource networkSecurityGroupRuleATM 'Microsoft.Network/networkSecurityGroups/securityRules@2022-09-01' = {
  parent: networkSecurityGroup
  name: 'ATM'
  properties: {
    description: 'Allows ATM'
    protocol: '*'
    sourcePortRange: '*'
    destinationPortRange: '*'
    sourceAddressPrefix: 'AzureTrafficManager'
    destinationAddressPrefix: '*'
    access: 'Allow'
    priority: 2001
    direction: 'Inbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
  }
}

resource networkSecurityGroupRuleHTTPS 'Microsoft.Network/networkSecurityGroups/securityRules@2022-09-01' = {
  parent: networkSecurityGroup
  name: 'HTTPS'
  properties: {
    description: 'Allows anyone to access the sever via port 443'
    protocol: '*'
    sourcePortRange: '*'
    destinationPortRange: '443'
    sourceAddressPrefix: '*'
    destinationAddressPrefix: '*'
    access: 'Allow'
    priority: 2002
    direction: 'Inbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
  }
}

resource networkSecurityGroupRuleDNS 'Microsoft.Network/networkSecurityGroups/securityRules@2022-09-01' = {
  parent: networkSecurityGroup
  name: 'DNS'
  properties: {
    description: 'Allows anyone to access the sever via port 53'
    protocol: '*'
    sourcePortRange: '*'
    destinationPortRange: '53'
    sourceAddressPrefix: '*'
    destinationAddressPrefix: '*'
    access: 'Allow'
    priority: 2003
    direction: 'Inbound'
    sourcePortRanges: []
    destinationPortRanges: []
    sourceAddressPrefixes: []
    destinationAddressPrefixes: []
  }
}
