@description('Azure Datacenter location for the resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machine Scale Set')
param virtualMachineScaleSet_AdminUsername string

@description('Password for the admin account of the Virtual Machine Scale Set')
@secure()
param virtualMachineScaleSet_AdminPassword string

@description('Size of the Virtual Machine Scale Set instances')
param virtualMachineScaleSet_Size string = 'Standard_D2_v5'

@description('Number of instances in the Virtual Machine Scale Set')
@minValue(1)
@maxValue(1000)
param instanceCount int = 2

@description('''True enables Accelerated Networking and False disables it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
var acceleratedNetworking bool = true

// Source Virtual Network for the VMSS
resource srcVNET 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: 'srcVNET'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'vmss-subnet'
        properties: {
          addressPrefix: '10.0.0.0/20'  // 4091 usable IPs for 301 VMs
        }
      }
    ]
  }
}

// Destination Virtual Network
resource dstVNET 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: 'dstVNET'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'general-subnet'
        properties: {
          addressPrefix: '10.1.0.0/20'
        }
      }
    ]
  }
}

// VNet Peering: Source to Destination
resource peering_src_to_dst 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = {
  parent: srcVNET
  name: 'srcVNET-to-dstVNET'
  properties: {
    remoteVirtualNetwork: {
      id: dstVNET.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// VNet Peering: Destination to Source
resource peering_dst_to_src 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01' = {
  parent: dstVNET
  name: 'dstVNET-to-srcVNET'
  properties: {
    remoteVirtualNetwork: {
      id: srcVNET.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// Destination Linux VM
module dstVM '../../../modules/Microsoft.Compute/VirtualMachine/Linux/Ubuntu24_Default.bicep' = {
  name: 'dstVM'
  params: {
    location: location
    virtualMachine_Name: 'dstVM'
    virtualMachine_Size: virtualMachineScaleSet_Size
    virtualMachine_AdminUsername: virtualMachineScaleSet_AdminUsername
    virtualMachine_AdminPassword: virtualMachineScaleSet_AdminPassword
    acceleratedNetworking: acceleratedNetworking
    subnet_ID: dstVNET.properties.subnets[0].id
    privateIPAllocationMethod: 'Static'
    privateIPAddress: '10.1.0.4'
  }
}

// Source Ubuntu 22 Virtual Machine Scale Set
module srcVMSS '../../../modules/Microsoft.Compute/VirtualMachineScaleSets/Ubuntu22.bicep' = {
  name: 'srcVMSS'
  params: {
    location: location
    virtualMachineScaleSet_Name: 'srcVMSS'
    virtualMachineScaleSet_Size: virtualMachineScaleSet_Size
    virtualMachineScaleSet_AdminUsername: virtualMachineScaleSet_AdminUsername
    virtualMachineScaleSet_AdminPassword: virtualMachineScaleSet_AdminPassword
    capacity: instanceCount
    acceleratedNetworking: acceleratedNetworking
    subnet_ID: srcVNET.properties.subnets[0].id
    virtualMachineScaleSet_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/refs/heads/main/scripts/'
    virtualMachineScaleSet_ScriptFileName: 'tcp-handshake-loop.py'
    commandToExecute: 'nohup python3 ./tcp-handshake-loop.py 10.1.0.4 22 10 > /dev/null 2>&1 &'
  }
}

// Bastion for connectivity to both VNets
module bastion '../../../modules/Microsoft.Network/BastionEverything.bicep' = {
  name: 'bastionAllResources'
  params: {
    location: location
    bastion_name: 'bastion'
    bastion_SKU: 'Standard'
    virtualNetwork_AddressPrefix: '10.100.0.0/24'
    peered_VirtualNetwork_Ids: [
      srcVNET.id
      dstVNET.id
    ]
  }
}

output vmss_Name string = srcVMSS.outputs.virtualMachineScaleSet_Name
