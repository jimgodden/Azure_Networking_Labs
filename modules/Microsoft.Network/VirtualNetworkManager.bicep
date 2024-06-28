@description('Azure Datacenter that the resource is deployed to')
param location string

@description('Prefix for the name of the Virtual Network Manager to ensure uniqueness')
param name_Prefix string = ''

@description('''Array of Network Manager Scope Subscriptions
Format: [ /subscriptions/xxx-xxx-xxx-xxx, /subscriptions/yyy-yyy-yyy-yyy ]''')
param networkManagerScopes_Subscriptions array = [
  '/subscriptions/${subscription().subscriptionId}'
]

@description('Array of Spoke Virtual Network Ids to be added to the Virtual Network Manager')
param VirtualNetwork_Spoke_Ids array

@description('Resource Id of the Hub Virtual Network to be added to the Virtual Network Manager')
param VirtualNetwork_Hub_Id string

@allowed([
  'dynamic'
  'static'
])
param networkGroupMembershipType string

@description('This is the Azure Virtual Network Manager which will be used to implement the connected group for inter-vnet connectivity.')
resource networkManager 'Microsoft.Network/networkManagers@2022-09-01' = {
  name: '${name_Prefix}VirtualNetworkManager'
  location: location
  properties: {
    networkManagerScopeAccesses: [
      'Connectivity'
    ]
    networkManagerScopes: {
      subscriptions: networkManagerScopes_Subscriptions
      managementGroups: []
    }
  }
}

@description('This is the dynamic group for all VNETs.')
resource networkGroupSpokesDynamic 'Microsoft.Network/networkManagers/networkGroups@2022-09-01' = if (networkGroupMembershipType == 'dynamic') {
  name: '${name_Prefix}networkGroups-Dynamic'
  parent: networkManager
  properties: {
    description: 'Network Group - Dynamic'
  }
}

@description('This is the static network group for the all VNETs.')
resource networkGroupSpokesStatic 'Microsoft.Network/networkManagers/networkGroups@2022-09-01' = if (networkGroupMembershipType == 'static') {
  name: '${name_Prefix}networkGroups-Static'
  parent: networkManager
  properties: {
    description: 'Network Group - Static'
  }

  // add spoke vnets A, B, and C to the static network group
  resource staticMemberSpoke 'staticMembers@2022-09-01' = [for VirtualNetwork_Spoke_Ids in VirtualNetwork_Spoke_Ids: {
    name: '${name_Prefix}sm-${(last(split(VirtualNetwork_Spoke_Ids, '/')))}'
    properties: {
      resourceId: VirtualNetwork_Spoke_Ids
    }
  }]

  resource staticMemberHub 'staticMembers@2022-09-01' = {
    name: '${name_Prefix}sm-${(toLower(last(split(VirtualNetwork_Hub_Id, '/'))))}'
    properties: {
      resourceId: VirtualNetwork_Hub_Id
    }
  }
}

@description('This connectivity configuration defines the connectivity between VNETs using Direct Connection. The hub will be part of the mesh, but gateway routes from the hub will not propagate to spokes.')
resource connectivityConfigurationMesh 'Microsoft.Network/networkManagers/connectivityConfigurations@2022-09-01' = {
  name: '${name_Prefix}connectivityConfigurations-mesh'
  parent: networkManager
  properties: {
    description: 'Mesh connectivity configuration'
    appliesToGroups: [
      {
        networkGroupId: (networkGroupMembershipType == 'static') ? networkGroupSpokesStatic.id : networkGroupSpokesDynamic.id
        isGlobal: 'False'
        useHubGateway: 'False'
        groupConnectivity: 'DirectlyConnected'
      }
    ]
    connectivityTopology: 'Mesh'
    deleteExistingPeering: 'True'
    hubs: []
    isGlobal: 'False'
  }
}
