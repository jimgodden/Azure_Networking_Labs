@description('Azure Datacenter location for the source resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

// @description('Change this to true if you want an Azure Bastion deployed')
// param deployBastion bool = false

// @description('Public IP Address of the user.  This will be added to an NSG rule to allow SSH access to the VMs')
// param UserPublicIPAddress string = 'Enter_your_public_IP_address_here'

@description('Size of the Virtual Machines')
var virtualMachine_Size = 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
var acceleratedNetworking = false

param tagValues object = { Training: 'BGPLab' }

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

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

// resource nsgRule_AllowUserSSH 'Microsoft.Network/networkSecurityGroups/securityRules@2022-09-01' = {
//   parent: networkSecurityGroup
//   name: 'AllowUserSSH'
//   properties: {
//     access: 'Allow'
//     direction: 'Inbound'
//     priority: 100
//     protocol: 'Tcp'
//     sourceAddressPrefix: UserPublicIPAddress
//     sourcePortRange: '*'
//     destinationAddressPrefix: '*'
//     destinationPortRange: '22'
//   }
// }

module VM01 '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = {
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
    privateIPAddress: '10.100.1.10'
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'frrconfig.sh'
    commandToExecute: './frrconfig.sh'
    addPublicIPAddress: true
  }
}

module VM02 '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = {
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
    privateIPAddress: '10.100.2.20'
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'frrconfig.sh'
    commandToExecute: './frrconfig.sh'
    addPublicIPAddress: true
  }
}

module VM03 '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = {
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
    privateIPAddress: '10.100.3.30'
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'frrconfig.sh'
    commandToExecute: './frrconfig.sh'
    addPublicIPAddress: true
  }
}

module VM04 '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = {
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
    privateIPAddress: '10.100.4.40'
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'frrconfig.sh'
    commandToExecute: './frrconfig.sh'
    addPublicIPAddress: true
  }
}

module bastion '../../modules/Microsoft.Network/Bastion.bicep' = {          //if (deployBastion) {
  name: 'bastion'
  params: {
    bastion_name: 'Bastion'
    bastion_SubnetID: virtualNetwork.properties.subnets[0].id
    location: location
  }
}

output VM01_SSH_Config string = 'VM01 SSH Command: ssh ${virtualMachine_AdminUsername}@${VM01.outputs.networkInterface_PublicIPAddress}'
output VM02_SSH_Config string = 'VM02 SSH Command: ssh ${virtualMachine_AdminUsername}@${VM02.outputs.networkInterface_PublicIPAddress}'
output VM03_SSH_Config string = 'VM03 SSH Command: ssh ${virtualMachine_AdminUsername}@${VM03.outputs.networkInterface_PublicIPAddress}'
output VM04_SSH_Config string = 'VM04 SSH Command: ssh ${virtualMachine_AdminUsername}@${VM04.outputs.networkInterface_PublicIPAddress}'
