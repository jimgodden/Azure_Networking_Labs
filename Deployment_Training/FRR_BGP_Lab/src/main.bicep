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

var tagValues = { Training: 'BGPLab' }

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

var virtualNetwork_AddressPrefix = '10.100.0.0/16'

var subnet_AddressRangeCIDRs = [for i in range(0, 255): cidrSubnet(virtualNetwork_AddressPrefix, 24, i) ]

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
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: subnet_AddressRangeCIDRs[0]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'Subnet01'
        properties: {
          addressPrefix: subnet_AddressRangeCIDRs[1]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'Subnet02'
        properties: {
          addressPrefix: subnet_AddressRangeCIDRs[2]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled' 
        }
      }
      {
        name: 'Subnet03'
        properties: {
          addressPrefix: subnet_AddressRangeCIDRs[3]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled' 
        }
      }
      {
        name: 'Subnet04'
        properties: {
          addressPrefix: subnet_AddressRangeCIDRs[4]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      // {
      //   name: 'ClientSubnet'
      //   properties: {
      //     addressPrefix: subnet_AddressRangeCIDRs[5]
      //     delegations: []
      //     routeTable: {
      //       id: routeTable.id
      //     }
      //     privateEndpointNetworkPolicies: 'Disabled'
      //     privateLinkServiceNetworkPolicies: 'Enabled'
      //   }
      // }
    ]
    enableDdosProtection: false
  }
  tags: tagValues
}

// module VMs '../../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = [ for i in range(1, 4): {
//   name: 'VM0${i}'
//   params: {
//     acceleratedNetworking: acceleratedNetworking
//     location: location
//     subnet_ID: virtualNetwork.properties.subnets[i].id
//     virtualMachine_AdminPassword: virtualMachine_AdminPassword
//     virtualMachine_AdminUsername: virtualMachine_AdminUsername
//     virtualMachine_Name: 'VM0${i}'
//     virtualMachine_Size: virtualMachine_Size
//     privateIPAllocationMethod: 'Static'
//     privateIPAddress: '10.100.${i}.${i}0'
//     virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
//     virtualMachine_ScriptFileName: 'frrconfig.sh'
//     commandToExecute: './frrconfig.sh'
//   }
// } ]

// module Client_VM '../../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
//   name: 'Client_VM'
//   params: {
//     acceleratedNetworking: acceleratedNetworking
//     location: location
//     subnet_ID: virtualNetwork.properties.subnets[5].id
//     virtualMachine_AdminPassword: virtualMachine_AdminPassword
//     virtualMachine_AdminUsername: virtualMachine_AdminUsername
//     virtualMachine_Name: 'Client-VM'
//     virtualMachine_Size: virtualMachine_Size
//     virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
//     virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_WebServer.ps1'
//     commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_WebServer.ps1 -Username ${virtualMachine_AdminUsername}'
//   }
// }

// resource routeTable 'Microsoft.Network/routeTables@2022-09-01' = {
//   name: 'Client_RouteTable'
//   location: location
//   properties: {
//     disableBgpRoutePropagation: false
//     routes: [
//       {
//         name: 'RouteToOne'
//         properties: {
//           addressPrefix: '10.100.1.0/24'
//           nextHopType: 'VirtualAppliance'
//           nextHopIpAddress: '10.100.4.40'
//         }
//       }
//       {
//         name: 'RouteToTwo'
//         properties: {
//           addressPrefix: '10.100.2.0/24'
//           nextHopType: 'VirtualAppliance'
//           nextHopIpAddress: '10.100.4.40'
//         }
//       }
//       {
//         name: 'RouteToThree'
//         properties: {
//           addressPrefix: '10.100.3.0/24'
//           nextHopType: 'VirtualAppliance'
//           nextHopIpAddress: '10.100.4.40'
//         }
//       }
//     ]
//   }
//   tags: tagValues
// }

module bastion '../../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_name: 'Bastion'
    bastion_SubnetID: virtualNetwork.properties.subnets[0].id
    location: location
  }
}
