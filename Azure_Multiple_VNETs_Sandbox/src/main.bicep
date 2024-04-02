@description('Azure Datacenter location for the Hub and Spoke A resources')
param location string = resourceGroup().location

@description('Number of Virtual Networks desired')
param numberOfVirtualNetworks int = 100

module virtualNetwork_Hub '../../modules/Microsoft.Network/VirtualNetworkSimple.bicep' = [ for i in range(1, numberOfVirtualNetworks): {
  name: 'vnet${i}'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: location
    virtualNetwork_Name: 'vnet${i}'
  }
} ]

// module loadbalancers '../../modules/Microsoft.Network/InternalLoadBalancerEmpty.bicep' = [ for i in range(1, numberOfVirtualNetworks):  {
//   name: 'ilb${i}'
//   params: {
//     internalLoadBalancer_SubnetID: virtualNetwork_Hub[i].outputs.general_SubnetID
//     location: location
//   }
// } ]



