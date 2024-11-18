@description('Azure Datacenter that the resource is deployed to')
param location string

param backendAddressPool_Id string

@description('Name of the NIC of the Virtual Machine that will be put behind the Private Link Service and Load Balancer')
param networkInterface_Name array

@description('Subnet ID of the NIC of the Virtual Machine that will be put behind the Private Link Service and Load Balancer')
param networkInterface_SubnetID array

@description('Name of the ipconfig of the NIC of the Virtual Machine that will be put behind the Private Link Service and Load Balancer')
param networkInterface_IPConfig_Name array

param tagValues object = {}

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
              id: backendAddressPool_Id
            }
          ]
        }
      }
    ]
  }
  tags: tagValues
} ]
