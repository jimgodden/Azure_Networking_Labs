@description('Azure Datacenter location for the source resources')
param location string = resourceGroup().location

@description('Location of the Storage Account used for Azure Cloud Shell')
param location_StorageAccount string

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

@description('Name of the Student')
param student_Name string

@description('IP Address of the Student in CIDR notation')
param student_CIDR_IP string

@description('IP Address of the Facilitator in CIDR notation')
param facilitator_CIDR_IP string

@description('VPN Shared Key used for authenticating VPN connections')
@secure()
param vpn_SharedKey string

param tagValues object = { Training: 'VPNLab' }

var myVirtualNetwork_AddressPrefix = '10.0.0.0/16'
var AzureLabVnet_AddressPrefix = '10.3.0.0/16'
var SecretVnet_AddressPrefix = '10.7.0.0/16'

var myVirtualNetwork_subnet_AddressRangeCIDRs = [for i in range(0, 255): cidrSubnet(myVirtualNetwork_AddressPrefix, 24, i) ]
var AzureLabVnet_subnet_AddressRangeCIDRs = [for i in range(0, 255): cidrSubnet(myVirtualNetwork_AddressPrefix, 24, i) ]
var SecretVnet_subnet_AddressRangeCIDRs = [for i in range(0, 255): cidrSubnet(myVirtualNetwork_AddressPrefix, 24, i) ]

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

// Exercise 1: Start

resource myVirtualNetwork_Ex1 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: 'myVirtualNetwork_Ex1'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        myVirtualNetwork_AddressPrefix
      ]
    }
    subnets: [
      {
        name: 'subnet1'
        properties: {
          addressPrefix: myVirtualNetwork_subnet_AddressRangeCIDRs[0]
          networkSecurityGroup: {
            id: networkSecurityGroup_Ex1.id
          }
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: myVirtualNetwork_subnet_AddressRangeCIDRs[1]
          routeTable: {
            id: badRouteTable_Ex1.id
          }
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      // {
      //   name: 'AzureBastionSubnet'
      //   properties: {
      //     addressPrefix: myVirtualNetwork_subnet_AddressRangeCIDRs[2]
      //     delegations: []
      //     privateEndpointNetworkPolicies: 'Disabled'
      //     privateLinkServiceNetworkPolicies: 'Enabled' 
      //   }
      // }
    ]
    enableDdosProtection: false
  }
  tags: tagValues
}


resource networkSecurityGroup_Ex1 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'networkSecurityGroup_Ex1'
  location: location
  properties: {
  }
  tags: tagValues
}

resource badRouteTable_Ex1 'Microsoft.Network/routeTables@2023-11-01' = {
  name: 'badRouteTable_Ex1'
  location: location
  properties: {
    routes: [
      { 
        name: 'route1'
        properties: {
          addressPrefix: '0.0.0.0/1'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.255.255.255'
        }
      }
      {
        name: 'route2'
        properties: {
          addressPrefix: '128.0.0.0/1'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.255.255.255'
        }
      }
    ]
  }
}

module virtualNetworkGateway_Ex1 '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'virtualNetworkGateway_Ex1'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65515
    virtualNetworkGateway_Name: 'virtualNetworkGateway_Ex1'
    virtualNetworkGateway_Subnet_ResourceID: myVirtualNetwork_Ex1.properties.subnets[1].id
    tagValues: tagValues
  }
}

// Exercise 1: End




// Exercise 2-5: Start


resource AzureLabVnet 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: 'AzureLabVnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        AzureLabVnet_AddressPrefix
      ]
    }
    subnets: [
      {
        name: 'subnet1'
        properties: {
          addressPrefix: AzureLabVnet_subnet_AddressRangeCIDRs[0]
          networkSecurityGroup: {
            id: networkSecurityGroup_Ex1.id
          }
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: AzureLabVnet_subnet_AddressRangeCIDRs[1]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: AzureLabVnet_subnet_AddressRangeCIDRs[2]
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

resource SecretVnet 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: 'SecretVnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        SecretVnet_AddressPrefix
      ]
    }
    subnets: [
      {
        name: 'subnet1'
        properties: {
          addressPrefix: SecretVnet_subnet_AddressRangeCIDRs[0]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'subnet2'
        properties: {
          addressPrefix: SecretVnet_subnet_AddressRangeCIDRs[1]
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

resource primaryNSG 'Microsoft.Network/networkSecurityGroups@2022-09-01' = {
  name: 'primaryNSG'
  location: location
  properties: {
  }
  tags: tagValues
}

resource nsgRule_Users 'Microsoft.Network/networkSecurityGroups/securityRules@2023-11-01' = {
  parent: primaryNSG
  name: 'externalCidr'
  properties: {
    access: 'Allow'
    direction: 'Inbound'
    priority: 100
    sourceAddressPrefixes: [
      student_CIDR_IP
      facilitator_CIDR_IP
    ]
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
    protocol: '*'
  }
}

resource nsgRule_AllowIPSec 'Microsoft.Network/networkSecurityGroups/securityRules@2023-11-01' = {
  parent: primaryNSG
  name: 'Allow IPSec'
  properties: {
    access: 'Allow'
    direction: 'Inbound'
    priority: 110
    sourceAddressPrefix: 'AzureCloud.${location}'
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRanges: [
      '500'
      '4500'
    ]
    protocol: '*'
  }
}

resource nsgRule_AzureCloudShell 'Microsoft.Network/networkSecurityGroups/securityRules@2023-11-01' = {
  parent: primaryNSG
  name: 'Allow Azure Cloud Shell'
  properties: {
    access: 'Allow'
    direction: 'Inbound'
    priority: 120
    sourceAddressPrefix: 'AzureCloud.${location_StorageAccount}'
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRanges: [
      '443'
    ]
    protocol: '*'
  }
}

module virtualMachine_Windows '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: '${student_Name}-vm'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: myVirtualNetwork_Ex1.properties.subnets[0].id
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: '${student_Name}-vm'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
    addPublicIPAddress: true
  }
}

module virtualMachine_VyOS '../../modules/Microsoft.Compute/VyOS/VirtualMachine.bicep' = {
  name: '${student_Name}-secretvm'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: SecretVnet.properties.subnets[0].id
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: '${student_Name}-secretvm'
    virtualMachine_Size: virtualMachine_Size
    privateIPAllocationMethod: 'Static'
    privateIPAddress: cidrHost( myVirtualNetwork_Ex1.properties.subnets[1].properties.addressPrefix, 3 )
    addPublicIPAddress: true
  }
}




module bastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_name: 'bastion'
    bastion_SubnetID: myVirtualNetwork_Ex1.properties.subnets[2].id
    location: location
  }
}

module virtualNetworkGateway '../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'virtualNetworkGateway'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65515
    virtualNetworkGateway_Name: 'virtualNetworkGateway'
    virtualNetworkGateway_Subnet_ResourceID: myVirtualNetwork_Ex1.properties.subnets[1].id
  }
}

module virtualNetworkGatewayToSecretVM '../../modules/Microsoft.Network/Connection_and_LocalNetworkGateway.bicep' = {
  name: 'virtualNetworkGatewayToSecretVM'
  params: {
    location: location
    virtualNetworkGateway_ID: virtualNetworkGateway.outputs.virtualNetworkGateway_ResourceID
    vpn_Destination_ASN: 65000
    vpn_Destination_BGPIPAddress: virtualMachine_VyOS.outputs.networkInterface_PrivateIPAddress
    vpn_Destination_Name: 'toSecretVM'
    vpn_Destination_PublicIPAddress: virtualMachine_VyOS.outputs.networkInterface_PublicIPAddress
    vpn_SharedKey: vpn_SharedKey
  }
}
