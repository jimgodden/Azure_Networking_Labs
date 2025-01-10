@description('Azure Datacenter location for the source resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
var virtualMachine_Size = 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
var acceleratedNetworking = false

param tagValues object = { Training: 'BGPLab' }

// Use the following if the VMs need to skip the auto shutdown policy
// param tagValues object = { 
//   Training: 'BGPLab' 
//   CostControl: 'Ignore'
// }

var virtualNetwork_AddressPrefix = '10.100.0.0/16'

var subnet_AddressRangeCIDRs = [for i in range(0, 255): cidrSubnet(virtualNetwork_AddressPrefix, 24, i) ]

var subnet_Names = [
  'AzureBastionSubnet'
  'Subnet01'
  'Subnet02'
  'Subnet03'
  'Subnet04'
]

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: 'virtualNetwork'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetwork_AddressPrefix
      ]
    }
    subnets: [
      {
        name: subnet_Names[0]
        properties: {
          addressPrefix: subnet_AddressRangeCIDRs[0]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: subnet_Names[1]
        properties: {
          addressPrefix: subnet_AddressRangeCIDRs[1]
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: subnet_Names[2]
        properties: {
          addressPrefix: subnet_AddressRangeCIDRs[2]
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled' 
        }
      }
      {
        name: subnet_Names[3]
        properties: {
          addressPrefix: subnet_AddressRangeCIDRs[3]
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled' 
        }
      }
      {
        name: subnet_Names[4]
        properties: {
          addressPrefix: subnet_AddressRangeCIDRs[4]
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    enableDdosProtection: false
  }
  tags: tagValues
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'primaryNSG'
  location: location
  properties: {
  }
  tags: tagValues
}

module virtualMachine_VyOS_01 '../../../modules/Microsoft.Compute/VyOS/VirtualMachine.bicep' = {
  name: 'VM01'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork.properties.subnets[1].id
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'VM01'
    virtualMachine_Size: virtualMachine_Size
    privateIPAllocationMethod: 'Static'
    privateIPAddress: cidrHost( virtualNetwork.properties.subnets[1].properties.addressPrefix, 9 )
    
  }
}

module virtualMachine_VyOS_02 '../../../modules/Microsoft.Compute/VyOS/VirtualMachine.bicep' = {
  name: 'VM02'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork.properties.subnets[2].id
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'VM02'
    virtualMachine_Size: virtualMachine_Size
    privateIPAllocationMethod: 'Static'
    privateIPAddress: cidrHost( virtualNetwork.properties.subnets[2].properties.addressPrefix, 19 )
  }
}

module virtualMachine_VyOS_03 '../../../modules/Microsoft.Compute/VyOS/VirtualMachine.bicep' = {
  name: 'VM03'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork.properties.subnets[3].id
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'VM03'
    virtualMachine_Size: virtualMachine_Size
    privateIPAllocationMethod: 'Static'
    privateIPAddress: cidrHost( virtualNetwork.properties.subnets[3].properties.addressPrefix, 29 )
  }
}

module virtualMachine_VyOS_04 '../../../modules/Microsoft.Compute/VyOS/VirtualMachine.bicep' = {
  name: 'VM04'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork.properties.subnets[4].id
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'VM04'
    virtualMachine_Size: virtualMachine_Size
    privateIPAllocationMethod: 'Static'
    privateIPAddress: cidrHost( virtualNetwork.properties.subnets[4].properties.addressPrefix, 39 )
  }
}

module bastion '../../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_name: 'Bastion'
    bastion_SubnetID: virtualNetwork.properties.subnets[0].id
    location: location
    bastion_SKU: 'Standard'
    enableShareableLink: true
  }
}
