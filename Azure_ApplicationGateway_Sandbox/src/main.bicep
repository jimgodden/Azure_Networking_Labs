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

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'

var virtualMachine_Website_DomainName = 'contoso.com'

module virtualNetwork_Hub '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'VirtualNetworkHub'
  params: {
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    location: location
    virtualNetwork_Name: 'VirutalNetworkHub'
  }
}

module clientVM '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'clientVM'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    networkInterface_Name: 'clientVM_NetworkInterface'
    subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'clientVM'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}

module AppGW '../../modules/Microsoft.Network/ApplicationGateway_v2.bicep' = {
  name: 'AppGW'
  params: {
    applicationGateway_Name: 'AppGWv2'
    applicationGateway_PrivateIPAddress: parseCidr(virtualNetwork_Hub.outputs.applicationGateway_Subnet_AddressPrefix).lastUsable
    location: location
    applicationGateway_SubnetID: virtualNetwork_Hub.outputs.applicationGateway_SubnetID
    backendPoolFQDNs: [
      site.outputs.website_FQDN
      '${webServVM_Win.outputs.virtualMachine_Name}.${virtualMachine_Website_DomainName}'
      '${webServVM_Ubn.outputs.virtualMachine_Name}.${virtualMachine_Website_DomainName}'
    ]
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

module privateDNSZone_ContosoDotCom '../../modules/Microsoft.Network/PrivateDNSZone.bicep' = {
  name: 'contosoDotCom'
  params: {
    privateDNSZone_Name: virtualMachine_Website_DomainName
    virtualNetworkIDs: [virtualNetwork_Hub.outputs.virtualNetwork_ID]
    registrationEnabled: true
  }
}

module ARecord_AppGW '../../modules/Microsoft.Network/PrivateDNSZoneARecord.bicep' = {
  name: 'ARecord_AppGW'
  params: {
    ARecord_name: 'appgw'
    ipv4Address: AppGW.outputs.ApplicationGateway_FrontendIP_Private
    PrivateDNSZone_Name: privateDNSZone_ContosoDotCom.outputs.PrivateDNSZone_Name
  }
}

module webServVM_Win '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'webServVM_Win'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'webserVM-Win'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_WebServer.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_WebServer.ps1 -Username ${virtualMachine_AdminUsername} -FQDN webserverVM.${virtualMachine_Website_DomainName}'
  }
}

module webServVM_Ubn '../../modules/Microsoft.Compute/Ubuntu20/VirtualMachine.bicep' = {
  name: 'webServVM_Ubn'
  params: {
    acceleratedNetworking: acceleratedNetworking
    location: location
    subnet_ID: virtualNetwork_Hub.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'webServVM-Ubn'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'Ubuntu20_WebServer_Config.sh'
    commandToExecute: './Ubuntu20_WebServer_Config.sh webServVM-Ubn.${virtualMachine_Website_DomainName}'
  }
}

module hubBastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'hubBastion'
  params: {
    bastion_name: 'Bastion_Hub'
    bastion_SubnetID: virtualNetwork_Hub.outputs.bastion_SubnetID
    location: location
  }
}
