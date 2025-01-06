param NetworkSecurityGroup_Name string

param NetworkSecurityGroupRule_Name string

param NetworkSecurityGroupRule_Priority int

param NetworkSecurityGroupRule_Description string = 'Created via Bicep'

param NetworkSecurityGroupRule_Direction string

@allowed([
  'Allow'
  'Deny'
])
param NetworkSecurityGroupRule_Access string

@allowed([
  '*'
  'Tcp'
  'Udp'
  'Icmp'
  'Esp'
])
param NetworkSecurityGroupRule_Protocol string

param NetworkSecurityGroupRule_SourceAddressPrefix string

param NetworkSecurityGroupRule_SourcePortRange string

param NetworkSecurityGroupRule_DestinationAddressPrefix string

param NetworkSecurityGroupRule_DestinationPortRange string

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' existing = {
  name: NetworkSecurityGroup_Name
}

resource nsgRule 'Microsoft.Network/networkSecurityGroups/securityRules@2024-05-01' = {
  parent: nsg
  name: NetworkSecurityGroupRule_Name
  properties: {
    access: NetworkSecurityGroupRule_Access
    description: NetworkSecurityGroupRule_Description
    destinationAddressPrefix: NetworkSecurityGroupRule_DestinationAddressPrefix
    destinationPortRange: NetworkSecurityGroupRule_DestinationPortRange
    direction: NetworkSecurityGroupRule_Direction
    priority: NetworkSecurityGroupRule_Priority
    protocol: NetworkSecurityGroupRule_Protocol
    sourceAddressPrefix: NetworkSecurityGroupRule_SourceAddressPrefix
    sourcePortRange: NetworkSecurityGroupRule_SourcePortRange
  }
}
