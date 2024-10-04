@description('''Azure Region that the resources will be deployed to.
Example: eastus, westus, centralus''')
param location string

param publicLoadBalancer_Name string

param protocol string = 'TCP'

param frontendPort int = 80

param backendPort int = 80

param enableTcpReset bool = false

param enableFloatingIP bool = false

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: '${publicLoadBalancer_Name}_PIP'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2024-01-01' = {
  name: publicLoadBalancer_Name
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'fip'
        properties: {
          publicIPAddress: {
            id: publicIpAddress.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'bep'
      }
    ]
    loadBalancingRules: [
      {
        name: 'inboundRule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', publicLoadBalancer_Name, 'fip')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', publicLoadBalancer_Name, 'bep')
          }
          disableOutboundSnat: true // must be set to true when using the same fip for outbound and inbound rules
          protocol: protocol
          frontendPort: frontendPort
          backendPort: backendPort
          enableFloatingIP: enableFloatingIP
          idleTimeoutInMinutes: 4
          enableTcpReset: enableTcpReset
        }
      }
    ]
    outboundRules: [
      {
        name: 'outboundRule'
        properties: {
          frontendIPConfigurations: [
             {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', publicLoadBalancer_Name, 'fip')
             }
          ]
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', publicLoadBalancer_Name, 'bep')
          }
          protocol: 'All'
          idleTimeoutInMinutes: 4
          enableTcpReset: enableTcpReset
        }
      }
    ]
  }
}

output publicLoadBalancer_Name string = loadBalancer.name
output publicLoadBalancer_ID string = loadBalancer.id
output publicIpAddress string = publicIpAddress.properties.ipAddress
output publicLoadBalancer_BackendAddressPoolID string = loadBalancer.properties.backendAddressPools[0].id
