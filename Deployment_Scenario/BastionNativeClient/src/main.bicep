param location string = resourceGroup().location

@description('Principal ID of the user to assign the Virtual Machine Administrator Login role to')
param principalId string

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param vmSize string = 'Standard_D2as_v4' // 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = true

param tagValues object = { Scenario: 'BastionNativeClient' }

var RoleDefinitionId_VmAdminLogin = '1c0163c0-47e6-4577-8991-ea5c82e286e4'

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: 'vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.1.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.1.1.0/24'
        }
      }
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
          sourceApplicationSecurityGroups: []
          destinationApplicationSecurityGroups: []
          description: ''
        }
      }
    ]
  }
}

module jumpboxVM '../../../modules/Microsoft.Compute/VirtualMachine/Windows/Server2025_General.bicep' = {
  name: 'jumpboxVM'
  params: {
    location: location
    acceleratedNetworking: acceleratedNetworking
    subnet_ID: vnet.properties.subnets[0].id
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'jumpboxVM'
    vmSize: vmSize
    entraConnect: false
    addPublicIPAddress: true
    tagValues: tagValues
  }
}

module clientVM '../../../modules/Microsoft.Compute/VirtualMachine/Windows/Server2025_General.bicep' = {
  name: 'clientVM'
  params: {
    location: location
    acceleratedNetworking: acceleratedNetworking
    subnet_ID: vnet.properties.subnets[0].id
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'clientVM'
    vmSize: vmSize
    entraConnect: false
    addPublicIPAddress: false
    tagValues: tagValues
  }
}

// assigns the Virtual Machine Administrator Login role to the user specified by the principalId parameter 
// (principalId is the Object ID from Entra of the user)
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(principalId, RoleDefinitionId_VmAdminLogin, resourceGroup().id)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', RoleDefinitionId_VmAdminLogin)
    principalId: principalId
  }
}

module bastion '../../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    location: location
    bastion_SubnetID: vnet.properties.subnets[1].id
    bastion_name: 'bastion'
    bastion_SKU: 'Standard'
    enableTunneling: true
    enableKerberos: true
  }
}
