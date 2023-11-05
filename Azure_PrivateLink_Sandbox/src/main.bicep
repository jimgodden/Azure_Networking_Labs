@description('Azure Datacenter location for the Hub and Spoke A resources')
param locationA string = resourceGroup().location

@description('''
Azure Datacenter location for the Spoke B resources.  
Use the same region as locationA if you do not want to test multi-region
''')
param locationB string = locationA

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_adminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_adminPassword string

@description('Password for the Virtual Machine Admin User')
param virtualMachine_Size string = 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = false

@description('''
Storage account name restrictions:
- Storage account names must be between 3 and 24 characters in length and may contain numbers and lowercase letters only.
- Your storage account name must be unique within Azure. No two storage accounts can have the same name.
''')
@minLength(3)
@maxLength(24)
param storageAccount_Name string

@description('Set this to true if you want to use an Azure Firewall in the Hub Virtual Network.')
param usingAzureFirewall bool = true


module virtualNetwork_Hub '../../modules/Microsoft.Network/VirtualNetworkHub.bicep' = {
  name: 'hubVNet'
  params: {
    firstTwoOctetsOfVirtualNetworkPrefix: '10.0'
    location: locationA
    networkSecurityGroup_Default_Name: 'nsg_hub'
    routeTable_Name: 'rt_hub'
    virtualNetwork_Name: 'vnet_hub'
  }
}

module virtualNetwork_Spoke_A '../../modules/Microsoft.Network/VirtualNetworkSpoke.bicep' = {
  name: 'spokeAVNet'
  params: {
    firstTwoOctetsOfVirtualNetworkPrefix: '10.1'
    location: locationA
    networkSecurityGroup_Default_Name: 'nsg_spokeA'
    routeTable_Name: 'rt_spokeA'
    virtualNetwork_Name: 'vnet_SpokeA'
  }
}



module hubToSpokeAPeering '../../modules/Microsoft.Network/VirtualNetworkPeering.bicep' = {
  name: 'hubToSpokeAPeering'
  params: {
    virtualNetwork_Source_Name: virtualNetwork_Hub.outputs.virtualNetwork_Name
    virtualNetwork_Destination_Name: virtualNetwork_Spoke_A.outputs.virtualNetwork_Name
  }
}

module virtualNetwork_Spoke_B '../../modules/Microsoft.Network/VirtualNetworkSpoke.bicep' = {
  name: 'spokeBVNet'
  params: {
    firstTwoOctetsOfVirtualNetworkPrefix: '10.2'
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

module hubVM_Windows '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'hubVM_Windows'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationA
    subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_adminPassword
    virtualMachine_AdminUsername: virtualMachine_adminUsername
    virtualMachine_Name: 'hubVM-Windows'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'
    virtualMachine_ScriptFileName: 'WinServ2022_DNS_InitScript.ps1'
  }
}

module spokeAVM_Windows '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'spokeAVM_Windows'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationA
    subnet_ID: virtualNetwork_Spoke_A.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_adminPassword
    virtualMachine_AdminUsername: virtualMachine_adminUsername
    virtualMachine_Name: 'spokeAVM-Windows'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'
    virtualMachine_ScriptFileName: 'WinServ2022_General_InitScript.ps1'
  }
}

module spokeBVM_Windows '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'spokeBVM_Windows'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: locationB
    subnet_ID: virtualNetwork_Spoke_B.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_adminPassword
    virtualMachine_AdminUsername: virtualMachine_adminUsername
    virtualMachine_Name: 'spokeBVM-Windows'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'
    virtualMachine_ScriptFileName: 'WinServ2022_WebServer_InitScript.ps1'
  }
}

module privateLink '../../modules/Microsoft.Network/PrivateLink.bicep' = {
  name: 'privateLink'
  params: {
    internalLoadBalancer_SubnetID: virtualNetwork_Spoke_B.outputs.general_SubnetID
    location: locationB
    networkInterface_IPConfig_Name: spokeAVM_Windows.outputs.networkInterface_IPConfig0_Name
    networkInterface_Name: spokeAVM_Windows.outputs.networkInterface_Name
    networkInterface_SubnetID: virtualNetwork_Spoke_B.outputs.general_SubnetID
    privateEndpoint_SubnetID: virtualNetwork_Spoke_B.outputs.privateEndpoint_SubnetID
    privateLink_SubnetID: virtualNetwork_Spoke_B.outputs.privateLinkService_SubnetID
  }
}

module storageAccount '../../modules/Microsoft.Storage/StorageAccount.bicep' = {
  name: 'storageAccount'
  params: {
    location: locationB
    privateEndpoints_Blob_Name: '${storageAccount_Name}_blob_pe'
    storageAccount_Name: storageAccount_Name
    privateEndpoint_SubnetID: virtualNetwork_Spoke_A.outputs.privateEndpoint_SubnetID
    privateDNSZoneLinkedVnetIDList: [virtualNetwork_Hub.outputs.virtualNetwork_ID, virtualNetwork_Spoke_A.outputs.virtualNetwork_ID, virtualNetwork_Spoke_B.outputs.virtualNetwork_ID]
    privateDNSZoneLinkedVnetNamesList: [virtualNetwork_Hub.outputs.virtualNetwork_Name, virtualNetwork_Spoke_A.outputs.virtualNetwork_Name, virtualNetwork_Spoke_B.outputs.virtualNetwork_Name]
    privateEndpoint_VirtualNetwork_Name: virtualNetwork_Spoke_A.outputs.virtualNetwork_Name
  }
  // Added this dependancy so that the VMs can reach out to my other Storage Account to download a file
  // Since my other Storage Account has a private endpoint, the connectivity fails because I don't have an
  //  entry in my Private DNS Zone for the other Storage Account.
  dependsOn: [
    hubVM_Windows
    spokeAVM_Windows
    spokeBVM_Windows
  ]
}

module azureFirewall '../../modules/Microsoft.Network/AzureFirewall.bicep' = if (usingAzureFirewall) {
  name: 'hubAzureFirewall'
  params: {
    azureFirewall_ManagementSubnet_ID: virtualNetwork_Hub.outputs.azureFirewallManagement_SubnetID
    azureFirewall_Name: 'hubAzFW'
    azureFirewall_SKU: 'Basic'
    azureFirewall_Subnet_ID: virtualNetwork_Hub.outputs.azureFirewall_SubnetID
    azureFirewallPolicy_Name: 'hubAzFW_Policy'
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
