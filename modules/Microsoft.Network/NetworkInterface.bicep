@description('Azure Datacenter that the resource is deployed to')
param location string

@description('Name of the Virtual Machines Network Interface')
param networkInterface_Name string

@description('True enables Accelerated Networking and False disabled it.  Not all virtualMachine sizes support Accel Net')
param acceleratedNetworking bool

@description('Sets the allocation mode of the IP Address of the Network Interface to either Dynamic or Static.')
@allowed([
  'Dynamic'
  'Static'
])
param privateIPAllocationMethod string = 'Dynamic'

@description('Enter the Static IP Address here if privateIPAllocationMethod is set to Static.')
param privateIPAddress string = ''

@description('The Resource ID of the subnet to which the Network Interface will be assigned.')
param subnet_ID string

@description('Adds a Public IP to the Network Interface of the Virtual Machine if true.')
param addPublicIPAddress bool = false

param tagValues object = {}

resource networkInterfaceWithoutPubIP 'Microsoft.Network/networkInterfaces@2022-09-01' = if (!addPublicIPAddress) {
  name: networkInterface_Name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig0'
        properties: {
          privateIPAllocationMethod: privateIPAllocationMethod
          subnet: {
            id: subnet_ID
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
          privateIPAddress: privateIPAddress
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
    enableIPForwarding: true
    disableTcpStateTracking: false
    nicType: 'Standard'
  }
  tags: tagValues
}

resource networkInterfaceWithPubIP 'Microsoft.Network/networkInterfaces@2022-09-01' = if (addPublicIPAddress) {
  name: networkInterface_Name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig0'
        properties: {
          privateIPAllocationMethod: privateIPAllocationMethod
          subnet: {
            id: subnet_ID
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
          privateIPAddress: privateIPAddress
          publicIPAddress: { 
            id: publicIPAddress.id 
          }
        }
      }
    ]
    enableAcceleratedNetworking: acceleratedNetworking
    enableIPForwarding: false
    disableTcpStateTracking: false
    nicType: 'Standard'
  }
  tags: tagValues
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
  tags: tagValues
}

output networkInterface_Name string = addPublicIPAddress ? networkInterfaceWithoutPubIP.name : networkInterfaceWithPubIP.name
output networkInterface_ID string = addPublicIPAddress ? networkInterfaceWithoutPubIP.id : networkInterfaceWithPubIP.id

output networkInterface_IPConfig0_Name string = addPublicIPAddress ? networkInterfaceWithoutPubIP.properties.ipConfigurations[0].name : networkInterfaceWithPubIP.properties.ipConfigurations[0].name
output networkInterface_IPConfig0_ID string = addPublicIPAddress ? networkInterfaceWithoutPubIP.properties.ipConfigurations[0].id : networkInterfaceWithPubIP.properties.ipConfigurations[0].id
output networkInterface_PrivateIPAddress string = addPublicIPAddress ? networkInterfaceWithoutPubIP.properties.ipConfigurations[0].properties.privateIPAddress : networkInterfaceWithPubIP.properties.ipConfigurations[0].properties.privateIPAddress

output networkInterface_PublicIPAddress string = addPublicIPAddress ? publicIPAddress.properties.ipAddress : ''
