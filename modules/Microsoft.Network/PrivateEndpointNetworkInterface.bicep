@description('Name of the Private Endpoint\'s Network Interface')
param existing_PrivateEndpoint_NetworkInterface_Name string

resource privateEndpoint_NIC 'Microsoft.Network/networkInterfaces@2023-05-01' existing = {
  name: existing_PrivateEndpoint_NetworkInterface_Name
}

output privateEndpoint_IPAddress string = privateEndpoint_NIC.properties.ipConfigurations[0].properties.privateIPAddress
