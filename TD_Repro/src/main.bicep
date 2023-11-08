@description('Azure Datacenter location for the Hub and Spoke A resources')
param locationA string = 'eastus'

@description('''
Azure Datacenter location for the Spoke B resources.  
Use the same region as locationA if you do not want to test multi-region
''')
param locationB string = 'westeurope'

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_adminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_adminPassword string

@description('Password for the Virtual Machine Admin User')
param virtualMachine_Size string = 'Standard_D2s_v3'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = true

param aaron bool = false


module virtualNetwork_Hub '../../modules/Microsoft.Network/VirtualNetworkHub.bicep' = {
  name: 'hubVNet'
  params: {
    firstTwoOctetsOfVirtualNetworkPrefix: '10.100'
    location: locationA
    networkSecurityGroup_Default_Name: 'nsg_hub'
    routeTable_Name: 'rt_hub'
    virtualNetwork_Name: 'vnet_hub'
  }
}

module virtualNetwork_Spoke_B '../../modules/Microsoft.Network/VirtualNetworkSpoke.bicep' = {
  name: 'spokeBVNet'
  params: {
    firstTwoOctetsOfVirtualNetworkPrefix: '10.101'
    location: locationB
    networkSecurityGroup_Default_Name: 'nsg_SpokeB'
    routeTable_Name: 'rt_SpokeB'
    virtualNetwork_Name: 'VNet_SpokeB'
  }
}
module hubToSpokeBPeering '../../modules/Microsoft.Network/VirtualNetworkPeering.bicep' = {
  name: 'hubToSpokeBPeering'
  params: {
    virtualNetwork_Source_Name: virtualNetwork_Hub.outputs.virtualNetwork_Name
    virtualNetwork_Destination_Name: virtualNetwork_Spoke_B.outputs.virtualNetwork_Name
  }
}

module hubVM_Linux '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = {
  name: 'hubvm'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationA
    subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_adminPassword
    virtualMachine_AdminUsername: virtualMachine_adminUsername
    virtualMachine_Name: 'hubVM-Linux'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: 'https://github.com/jimgodden/Azure_Networking_Labs/tree/main/scripts/'
    virtualMachine_ScriptFileName: 'conntest'
    commandToExecute: 'nohup ./conntest -c ${ilb.outputs.frontendIPAddress} -p 5001 &'
  }
  dependsOn: [
    SpokeBVM_Linux1
    SpokeBVM_Linux2
  ]
}

module SpokeBVM_Linux1 '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = {
  name: 'spokebVMlin1'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationB
    subnet_ID: virtualNetwork_Spoke_B.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_adminPassword
    virtualMachine_AdminUsername: virtualMachine_adminUsername
    virtualMachine_Name: 'destVM1'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: 'https://github.com/jimgodden/Azure_Networking_Labs/tree/main/scripts/'
    virtualMachine_ScriptFileName: 'conntest'
    commandToExecute: 'nohup ./contest -s -p 5001 &'
  }
}

module SpokeBVM_Linux2 '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = {
  name: 'spokebVMlin2'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationB
    subnet_ID: virtualNetwork_Spoke_B.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_adminPassword
    virtualMachine_AdminUsername: virtualMachine_adminUsername
    virtualMachine_Name: 'destvm2'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: 'https://github.com/jimgodden/Azure_Networking_Labs/tree/main/scripts/'
    virtualMachine_ScriptFileName: 'conntest'
    commandToExecute: 'nohup ./contest -s -p 5001 &'
  }
}

module ilb '../../modules/Microsoft.Network/InternalLoadBalancer.bicep' = {
  name: 'ilb'
  params: {
    internalLoadBalancer_SubnetID: virtualNetwork_Spoke_B.outputs.general_SubnetID
    location: locationB
    networkInterface_IPConfig_Name: [SpokeBVM_Linux1.outputs.networkInterface_IPConfig0_Name, SpokeBVM_Linux2.outputs.networkInterface_IPConfig0_Name ]
    networkInterface_Name: [SpokeBVM_Linux1.outputs.networkInterface_Name, SpokeBVM_Linux2.outputs.networkInterface_Name]
    networkInterface_SubnetID: [virtualNetwork_Spoke_B.outputs.general_SubnetID, virtualNetwork_Spoke_B.outputs.general_SubnetID]
  }
}

module firewall '../../modules/Microsoft.Network/AzureFirewall.bicep' = if (!aaron) {
  name: 'azfw'
  params: {
    azureFirewall_ManagementSubnet_ID: virtualNetwork_Hub.outputs.azureFirewallManagement_SubnetID
    azureFirewall_Name: 'azfw'
    azureFirewall_SKU: 'Basic'
    azureFirewall_Subnet_ID: virtualNetwork_Hub.outputs.azureFirewall_SubnetID
    azureFirewallPolicy_Name: 'azfw_policy'
    location: locationA
  }
}

module firewallAaron '../../modules/Microsoft.Network/AzureFirewall.bicep' =  if (aaron)  {
  name: 'azfwAaron'
  params: {
    azureFirewall_ManagementSubnet_ID: '/subscriptions/e155f4a6-30c5-486c-8195-ef8d969f45ae/resourceGroups/rg0002_scus/providers/Microsoft.Network/virtualNetworks/SCUS-HUBVNET/subnets/AzureFirewallManagementSubnet'
    azureFirewall_Name: 'azfw'
    azureFirewall_SKU: 'Basic'
    azureFirewall_Subnet_ID: '/subscriptions/e155f4a6-30c5-486c-8195-ef8d969f45ae/resourceGroups/rg0002_scus/providers/Microsoft.Network/virtualNetworks/SCUS-HUBVNET/subnets/AzureFirewallSubnet'
    azureFirewallPolicy_Name: 'azfw_policy'
    location: locationA
  }
}

module hubBastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'hubBastion'
  params: {
    bastion_SubnetID: virtualNetwork_Hub.outputs.bastion_SubnetID
    location: locationA
  }
}

