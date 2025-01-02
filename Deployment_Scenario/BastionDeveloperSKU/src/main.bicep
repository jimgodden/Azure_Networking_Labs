@description('Azure Datacenter location for the source resources')
param location string = resourceGroup().location

// resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
//   name: 'vnet'
//   location: location
//   properties: {
//     addressSpace: {
//       addressPrefixes: [
//         '10.0.0.0/16'
//       ]
//     }
//   }
// }

// resource subnet1 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
//   parent: vnet
//   name: 'subnet1'
//   properties: {
//     addressPrefix: '10.0.0.0/24'
//   }
// }

module vnetbig '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnetbig'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    virtualNetwork_Name: 'vnetbig'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2024-01-01' = {
  name: 'bastion'
  location: location
  sku: {
    name: 'Developer'
  }
  properties: {
    dnsName: 'omnibrain.westus.bastionglobal.azure.com'
    scaleUnits: 2
    virtualNetwork: {
      id: vnetbig.outputs.virtualNetwork_ID
    }
  }
}
