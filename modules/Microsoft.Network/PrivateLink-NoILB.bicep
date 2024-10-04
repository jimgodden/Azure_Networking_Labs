@description('Azure Datacenter that the resource is deployed to')
param location string

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

@description('True enables Proxy Protocol and False disables it')
param enableProxyProtocol bool = false

param ilb_backendPool_Id string

param ilb_FrontendIPConfig_Id string

param populateBackendPool bool = true

param tagValues object = {}

// Modifies the existing Virtual Machine NIC to add it to the backend pool of the Load Balancer behind the Private Link Service
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-04-01' = [for i in range(0, length(networkInterface_Names)): if (populateBackendPool) {
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
              id:ilb_backendPool_Id
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
  tags: tagValues
} ]

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-09-01' = {
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
  tags: tagValues
}

resource privateLink 'Microsoft.Network/privateLinkServices@2022-09-01' = {
  name: privateLink_Name
  location: location
  properties: {
    enableProxyProtocol: enableProxyProtocol
    loadBalancerFrontendIpConfigurations: [
      {
        id: ilb_FrontendIPConfig_Id
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
  tags: tagValues
}

output privateEndpoint_NetworkInterface_Name string = privateEndpoint.properties.customNetworkInterfaceName
