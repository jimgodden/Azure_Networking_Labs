@description('Azure Datacenter that the resource is deployed to')
param location string

@description('Name of the Azure Load Balancer')
param externalLoadBalancer_Name string

@description('Name of the NIC of the Virtual Machine that will be put behind the Private Link Service and Load Balancer')
param networkInterface_Name array

@description('Subnet ID of the NIC of the Virtual Machine that will be put behind the Private Link Service and Load Balancer')
param networkInterface_SubnetID array

@description('Name of the ipconfig of the NIC of the Virtual Machine that will be put behind the Private Link Service and Load Balancer')
param networkInterface_IPConfig_Name array

@description('TCP Port that will be used for connecting to the Virtual Machine behind the Private Link Service and Load Balancer')
param tcpPort int = 443

@description('Set to true to enable TCP Resets from the Load Balancer for idle connections')
param enableTcpReset bool = false

param tagValues object = {}

resource basicPubIP_Dynamic 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: '${externalLoadBalancer_Name}_Basic_publicIP'
  location: location
  sku: {
    name: 'Basic'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

// Modifies the existing Virtual Machine NIC to add it to the backend pool of the Load Balancer behind the Private Link Service
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-04-01' = [ for i in range(0, length(networkInterface_Name)): {
  name: networkInterface_Name[i]
  location: location
  properties: {
    ipConfigurations: [
      {
        name: networkInterface_IPConfig_Name[i]
        properties: {
          subnet: {
            id: networkInterface_SubnetID[i]
          }
          loadBalancerBackendAddressPools: [
            {
              id: externalLoadBalancer.properties.backendAddressPools[0].id
            }
          ]
        }
      }
    ]
  }
  tags: tagValues
} ]

resource externalLoadBalancer 'Microsoft.Network/loadBalancers@2022-09-01' = {
  name: externalLoadBalancer_Name
  location: location
  sku: {
    name: 'Basic'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'fip'
        properties: {
          publicIPAddress: {
            id: basicPubIP_Dynamic.id
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
        name: 'forward${tcpPort}'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', externalLoadBalancer_Name, 'fip')
          }
          frontendPort: tcpPort
          backendPort: tcpPort
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
          protocol: 'TCP'
          enableTcpReset: enableTcpReset
          loadDistribution: 'Default'
          disableOutboundSnat: false
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', externalLoadBalancer_Name, 'bep')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', externalLoadBalancer_Name, 'probe${tcpPort}')
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
