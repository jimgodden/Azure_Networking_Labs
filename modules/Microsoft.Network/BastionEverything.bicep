@description('Azure Datacenter location that the main resouces will be deployed to.')
param location string

@description('Name of the Azure Bastion')
param bastion_name string

param bastion_SKU string = 'Standard'

param peered_VirtualNetwork_Ids array

param virtualNetwork_AddressPrefix string

resource bastionVNET 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: '${bastion_name}_vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetwork_AddressPrefix
      ]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: virtualNetwork_AddressPrefix
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    enableDdosProtection: false
  }
}

module bastion 'Bastion.bicep' = {
  name: bastion_name
  params: {
    location: location
    bastion_SubnetID: bastionVNET.properties.subnets[0].id
    bastion_name: bastion_name
    bastion_SKU: bastion_SKU
  }
}

module bastionVNETPeering 'BastionVirtualNetworkHubPeerings.bicep' = {
  name: 'bastionVNETPeering'
  params: {
    bastion_VirtualNetwork_Id: bastionVNET.id
    other_VirtualNetwork_Ids: peered_VirtualNetwork_Ids
  }
}
