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


resource Router_VNets 'Microsoft.Network/virtualNetworks@2022-09-01' = [ for i in range(1, 4):  {
  name: 'Router_VNet${i}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.100.${i}.0/24'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.100.${i}.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    enableDdosProtection: false
  }
  tags: tagValues
} ]

module Router_VNetsPeerings '../../modules/Microsoft.Network/VirtualNetworkPeeringSpoke2SpokeusingIds.bicep' = [ for i in range(0, 2): {
  name: 'Router_VNetsPeerings${i}'
  params: {
    virtualNetwork1_Id: Router_VNets[i].id
    virtualNetwork2_Id: Router_VNets[i+1].id
  }
} ]

module Router_VNetsPeering_TwoToFour '../../modules/Microsoft.Network/VirtualNetworkPeeringSpoke2SpokeusingIds.bicep' = {
  name: 'Router_VNetsPeering_TwoToFour'
  params: {
    virtualNetwork1_Id: Router_VNets[1].id
    virtualNetwork2_Id: Router_VNets[3].id
  }
  dependsOn: [
    Router_VNetsPeerings
  ]
}

module Router_VMs '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = [ for i in range(1, 4): {
  name: 'VM0${i}'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: Router_VNets[i-1].properties.subnets[0].id
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'VM0${i}'
    virtualMachine_Size: virtualMachine_Size
    privateIPAllocationMethod: 'Static'
    privateIPAddress: '10.100.${i}.${i}0'
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'frrconfig.sh'
    commandToExecute: './frrconfig.sh'
  }
} ]

resource Client_VNet 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: 'Client_VNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.100.5.0/24'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.100.5.0/24'
          routeTable: {
            id: routeTable.id
          }
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    enableDdosProtection: false
  }
  tags: tagValues
}

module clientPeeringToRouterVNet '../../modules/Microsoft.Network/VirtualNetworkPeeringSpoke2SpokeusingIds.bicep' = {
  name: 'clientPeeringToRouterVNets'
  params: {
    virtualNetwork1_Id: Client_VNet.id
    virtualNetwork2_Id: Router_VNets[3].id
  }
  dependsOn: [
    Router_VNetsPeerings
  ]
}

resource routeTable 'Microsoft.Network/routeTables@2022-09-01' = {
  name: 'Client_RouteTable'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'RouteToOne'
        properties: {
          addressPrefix: '10.100.1.0/24'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: Router_VMs[3].outputs.networkInterface_PrivateIPAddress
        }
      }
      {
        name: 'RouteToTwo'
        properties: {
          addressPrefix: '10.100.2.0/24'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: Router_VMs[3].outputs.networkInterface_PrivateIPAddress
        }
      }
      {
        name: 'RouteToThree'
        properties: {
          addressPrefix: '10.100.3.0/24'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: Router_VMs[3].outputs.networkInterface_PrivateIPAddress
        }
      }
    ]
  }
  tags: tagValues
}

module Client_VM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'Client_VM'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: Client_VNet.properties.subnets[0].id
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'Client-VM'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_WebServer.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_WebServer.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}


resource Bastion_VNet 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: 'Bastion_VNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.100.0.0/24'
      ]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.100.0.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    enableDdosProtection: false
  }
  tags: tagValues
}

module bastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_name: 'Bastion'
    bastion_SubnetID: Bastion_VNet.properties.subnets[0].id
    location: location
  }
}

module bastionPeeringToRouterVNets '../../modules/Microsoft.Network/BastionVirtualNetworkHubPeerings.bicep' = {
  name: 'bastionPeeringToRouterVNets'
  params: {
    bastion_VirtualNetwork_Id: Bastion_VNet.id
    other_VirtualNetwork_Ids: [ for i in range(0, 4): Router_VNets[i].id ]
  }
  dependsOn: [
    Router_VNetsPeerings
  ]
}

module bastionPeeringToClientVNet '../../modules/Microsoft.Network/BastionVirtualNetworkHubPeerings.bicep' = {
  name: 'bastionPeeringToClientVNet'
  params: {
    bastion_VirtualNetwork_Id: Bastion_VNet.id
    other_VirtualNetwork_Ids: [ Client_VNet.id ]
  }
  dependsOn: [
    bastionPeeringToRouterVNets
  ]
}
