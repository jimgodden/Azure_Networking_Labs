@description('Azure Datacenter that the resource is deployed to')
param location string

@description('Name of the Azure Load Balancer')
param internalLoadBalancer_Name string = 'internalLoadBalancer'

@description('Subnet ID that the Load Balancer will be deployed to')
param internalLoadBalancer_SubnetID string

@description('TCP Port that will be used for connecting to the Virtual Machine behind the Private Link Service and Load Balancer')
param tcpPort int = 443

@description('Set to true to enable TCP Resets from the Load Balancer for idle connections')
param enableTcpReset bool = false

param tagValues object = {}

resource internalLoadBalancer 'Microsoft.Network/loadBalancers@2022-09-01' = {
  name: internalLoadBalancer_Name
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'fip'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: internalLoadBalancer_SubnetID
          }
          privateIPAddressVersion: 'IPv4'
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
        name: 'forwardAll'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', internalLoadBalancer_Name, 'fip')
          }
          frontendPort: 0
          backendPort: 0
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
          protocol: 'All'
          enableTcpReset: enableTcpReset
          loadDistribution: 'Default'
          disableOutboundSnat: true
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', internalLoadBalancer_Name, 'bep')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', internalLoadBalancer_Name, 'probe${tcpPort}')
          }
        }
      }
    ]
    probes: [
      {
        name: 'probe${tcpPort}'
        properties: {
          protocol: 'Tcp'
          port: tcpPort
          intervalInSeconds: 5
          numberOfProbes: 1
          probeThreshold: 1
        }
      }
    ]
    inboundNatRules: []
    outboundRules: []
    inboundNatPools: []
  }
  tags: tagValues
}

output frontendIPAddress string = internalLoadBalancer.properties.frontendIPConfigurations[0].properties.privateIPAddress
