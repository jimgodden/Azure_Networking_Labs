@description('Azure Datacenter that the resource is deployed to')
param location string

@description('Name of the Azure Load Balancer')
param internalLoadBalancer_Name string = 'internalLoadBalancer'

@description('Subnet ID that the Load Balancer will be deployed to')
param internalLoadBalancer_SubnetID string

@description('Name of the Private Endpoint')
param privateEndpoint_name string = 'pe_to_pl'

@description('Subnet ID that the Private Endpoint will be deployed to')
param privateEndpoint_SubnetID string

@description('Name of the Private Link Service')
param privateLink_Name string = 'pl'

@description('Subnet ID that the Private Link Service will be deployed to')
param privateLink_SubnetID string

@description('Name of the NIC of the Virtual Machine that will be put behind the Private Link Service and Load Balancer')
param networkInterface_Names array

@description('Subnet ID of the NIC of the Virtual Machine that will be put behind the Private Link Service and Load Balancer')
param networkInterface_SubnetID string

@description('Name of the ipconfig of the NIC of the Virtual Machine that will be put behind the Private Link Service and Load Balancer')
param networkInterface_IPConfig_Names array

@description('True enables Accelerated Networking and False disabled it.  Not all virtualMachine sizes support Accel Net')
param acceleratedNetworking bool

@description('TCP Port that will be used for connecting to the Virtual Machine behind the Private Link Service and Load Balancer')
param tcpPort int = 443

param enableTcpReset bool = false

// Modifies the existing Virtual Machine NIC to add it to the backend pool of the Load Balancer behind the Private Link Service
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-04-01' = [for i in range(0, length(networkInterface_Names)): {
  name: '${networkInterface_Names[i]}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: '${networkInterface_IPConfig_Names[i]}'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: networkInterface_SubnetID
          }
          loadBalancerBackendAddressPools: [
            {
              id: internalLoadBalancer.properties.backendAddressPools[0].id
            }
          ]
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
    enableIPForwarding: false
    disableTcpStateTracking: false
    nicType: 'Standard'
  }
} ]

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
}

resource privateendpoint 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: privateEndpoint_name
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: privateEndpoint_name
        properties: {
          privateLinkServiceId: privateLink.id
        }
      }
    ]
    manualPrivateLinkServiceConnections: []
    customNetworkInterfaceName: '${privateEndpoint_name}-nic'
    subnet: {
      id: privateEndpoint_SubnetID

    }
  }
}

resource privateLink 'Microsoft.Network/privateLinkServices@2022-09-01' = {
  name: privateLink_Name
  location: location
  properties: {
    enableProxyProtocol: false
    loadBalancerFrontendIpConfigurations: [
      {
        id: '${internalLoadBalancer.id}/frontendIPConfigurations/fip'
      }
    ]
    ipConfigurations: [
      {
        name: 'default-1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: privateLink_SubnetID
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
  }
}

output internalLoadBalancer_FrontendIPAddress string = internalLoadBalancer.properties.frontendIPConfigurations[0].properties.privateIPAddress
output privateEndpoint_NetworkInterface_Name string = privateendpoint.properties.customNetworkInterfaceName




















