param location string = resourceGroup().location

@description('Name of the App Service')
param site_Name string =  'anptestsite${substring(uniqueString(resourceGroup().id), 0, 5)}'

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Password for the Virtual Machine Admin User')
param virtualMachine_Size string = 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param acceleratedNetworking bool = false

module virtualNetwork_Hub '../../modules/Microsoft.Network/VirtualNetworkHub.bicep' = {
  name: 'VirtualNetworkHub'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: location
    virtualNetwork_Name: 'VirutalNetworkHub'
  }
}

module site '../../modules/Microsoft.Web/site.bicep' = {
  name: 'site'
  params: {
    appServicePlan_Name: 'asp'
    appServiceSubnet_ID: virtualNetwork_Hub.outputs.appService_SubnetID
    location: location
    site_Name: site_Name
    virtualNetwork_Name: virtualNetwork_Hub.outputs.virtualNetwork_Name 
  }
}

module AppGW '../../modules/Microsoft.Network/ApplicationGateway_v2.bicep' = {
  name: 'AppGW'
  params: {
    applicationGateway_Name: 'AppGWv2'
    publicIP_ApplicationGateway_Name: 'AppGW_PIP'
    applicationGateway_PrivateIP_Address: virtualNetwork_Hub.outputs.applicationGateway_PrivateIP
    applicationGatewayWAF_Name: 'AppGW_WAF'
    location: location
    applicationGateway_SubnetID: virtualNetwork_Hub.outputs.applicationGateway_SubnetID
    backendPoolFQDN: site.outputs.website_FQDN
  }
}

module clientVMWindows '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'clientVMWindows'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    networkInterface_Name: 'clientVMWindows_NetworkInterface'
    subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'clientVMWindows'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/buildtest/scripts/'
    virtualMachine_ScriptFileName: 'WinServ2022_General_InitScript.ps1'
  }
}


module hubBastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'hubBastion'
  params: {
    bastion_SubnetID: virtualNetwork_Hub.outputs.bastion_SubnetID
    location: location
  }
}
















