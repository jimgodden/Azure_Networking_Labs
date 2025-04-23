@description('Azure Datacenter location for the source resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param virtualMachine_Size string = 'Standard_D2as_v4' // 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@maxValue(20)
@description('Number of WebServers to create behind the Internal Load Balancer')
param WebServerCount int = 2

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = true

module virtualNetwork_Hub '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet-hub'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    virtualNetwork_Name: 'vnet-hub'
  }
}

module virtualNetwork_SpokeA '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet-spokeA'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.1.0.0/16'
    virtualNetwork_Name: 'vnet-spokeA'
  }
}

module virtualNetwork_SpokeB '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet-spokeB'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.2.0.0/16'
    virtualNetwork_Name: 'vnet-spokeB'
  }
}

module virtualMachine_DNS '../../../modules/Microsoft.Compute/VirtualMachine/Windows/Server2025_DNS.bicep' = {
  name: 'vm-dns'
  params: {
    location: location
    acceleratedNetworking: acceleratedNetworking
    subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'vm-dns'
    vmSize: virtualMachine_Size
    privateIPAddress: cidrHost( virtualNetwork_Hub.outputs.general_Subnet_AddressPrefix, 3 )
    privateIPAllocationMethod: 'Static'
  }
}

// module virtualNetwork_Hub_DNS_Update '../../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
//   name: 'vnet-hub-dns-update'
//   params: {
//     location: location
//     virtualNetwork_AddressPrefix: '10.0.0.0/16'
//     virtualNetwork_Name: 'vnet-hub'
//     dnsServers: [
//       virtualMachine_DNS.outputs.networkInterface_PrivateIPAddress
//     ]
//   }
// }

module virtualMachine_Client '../../../modules/Microsoft.Compute/VirtualMachine/Windows/Server2025_General.bicep' = {
  name: 'vm-client'
  params: {
    location: location
    acceleratedNetworking: acceleratedNetworking
    subnet_ID: virtualNetwork_SpokeA.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'vm-client'
    vmSize: virtualMachine_Size
    privateIPAllocationMethod: 'Static'
    privateIPAddress: cidrHost( virtualNetwork_SpokeA.outputs.general_Subnet_AddressPrefix, 3 )
  }
  // dependsOn: [
  //   virtualNetwork_Hub_DNS_Update
  // ]
}

module internalLoadBalancer_WebServers '../../../modules/Microsoft.Network/InternalLoadBalancer.bicep' = {
  name: 'ilb-webservers'
  params: {
    location: location
    internalLoadBalancer_Name: 'ilb-webservers'
    internalLoadBalancer_SubnetID: virtualNetwork_SpokeB.outputs.general_SubnetID
    tcpPort: 443
    networkInterface_IPConfig_Name: [ for i in range(0, WebServerCount): virtualMachine_WebServers[i].outputs.networkInterface_IPConfig0_Name ]
    networkInterface_Name: [ for i in range(0, WebServerCount): virtualMachine_WebServers[i].outputs.networkInterface_Name ]
    networkInterface_SubnetID: [ for i in range(0, WebServerCount): virtualNetwork_SpokeB.outputs.general_SubnetID]
  }
}

module virtualMachine_WebServers '../../../modules/Microsoft.Compute/VirtualMachine/Windows/Server2025_WebServer.bicep' = [ for i in range(1, WebServerCount): {
  name: 'vm-webserver${i}'
  params: {
    location: location
    acceleratedNetworking: acceleratedNetworking
    subnet_ID: virtualNetwork_SpokeB.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'vm-webserver${i}'
    vmSize: virtualMachine_Size
  }
} ]

module virtualNetworkGateway '../../../modules/Microsoft.Network/VirtualNetworkGateway.bicep' = {
  name: 'virtualNetworkGateway'
  params: {
    location: location
    virtualNetworkGateway_ASN: 65000
    virtualNetworkGateway_Name: 'virtualNetworkGateway'
    virtualNetworkGateway_Subnet_ResourceID: virtualNetwork_Hub.outputs.gateway_SubnetID
    virtualNetworkGateway_SKU: 'VpnGw1'
  }
}

module bastion '../../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_name: 'bastion'
    bastion_SubnetID: virtualNetwork_Hub.outputs.bastion_SubnetID
    location: location
    bastion_SKU: 'Basic'
  }
}
