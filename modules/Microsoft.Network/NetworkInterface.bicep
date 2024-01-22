param location string

@description('Name of the Virtual Machines Network Interface')
param networkInterface_Name string

@description('True enables Accelerated Networking and False disabled it.  Not all virtualMachine sizes support Accel Net')
param acceleratedNetworking bool

@description('The Resource ID of the subnet to which the Network Interface will be assigned.')
param subnet_ID string

@description('Adds a Public IP to the Network Interface of the Virtual Machine')
param addPublicIPAddress bool = false

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-09-01' = if (!addPublicIPAddress) {
  name: networkInterface_Name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig0'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet_ID
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
          publicIPAddress: {
            id: addPublicIPAddress ? publicIPAddress.id : ''
          }
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
    enableIPForwarding: false
    disableTcpStateTracking: false
    nicType: 'Standard'
  }
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2023-06-01' = if (addPublicIPAddress) {
  name: '${networkInterface_Name}_PIP'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    ipTags: []
  }
}




output networkInterface_Name string = networkInterface.name
output networkInterface_ID string = networkInterface.id

output networkInterface_IPConfig0_Name string = networkInterface.properties.ipConfigurations[0].name
output networkInterface_IPConfig0_ID string = networkInterface.properties.ipConfigurations[0].id
output networkInterface_PrivateIPAddress string = networkInterface.properties.ipConfigurations[0].properties.privateIPAddress




















