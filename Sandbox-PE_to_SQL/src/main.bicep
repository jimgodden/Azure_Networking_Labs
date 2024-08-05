@description('Azure Datacenter location for the source resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param virtualMachine_Size string = 'Standard_D2as_v4' // 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'
@description('Username for the admin account of the SQL Server')
param sql_AdministratorUsername string

@description('Password for the admin account of the SQL Server')
@secure()
param sql_AdministratorPassword string

@description('Name of the SQL Server')
param sqlServer_Name string = 'sql${uniqueString(resourceGroup().id)}'

@description('Sku name of the Azure Firewall.  Allowed values are Basic, Standard, and Premium')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param azureFirewall_SKU string = 'Basic'

@description('If true, an Azure Firewall will be deployed in both source and destination')
param isUsingAzureFirewall bool = true

var virtualMachine_ScriptFileLocation = 'https://raw.githubusercontent.com/jimgodden/Azure_Networking_Labs/main/scripts/'



module sql '../../modules/Microsoft.Sql/Server.bicep' = {
  name: 'sql'
  params: {
    location: location
    sql_AdministratorPassword: sql_AdministratorPassword
    sql_AdministratorUsername: sql_AdministratorUsername
    sqlServer_Name: sqlServer_Name
  }
}

module virtualNetwork '../../modules/Microsoft.Network/VirtualNetwork.bicep' = {
  name: 'vnet'
  params: {
    location: location
    virtualNetwork_AddressPrefix: '10.0.0.0/16'
    virtualNetwork_Name: 'vnet'
  }
}

module privateEndpoint_SQL '../../modules/Microsoft.Network/PrivateEndpoint.bicep' = {
  name: 'pe_sql'
  params: {
    groupID: 'sqlServer'
    location: location
    privateDNSZone_Name: 'privatelink${environment().suffixes.sqlServerHostname}'
    privateEndpoint_Name: 'pe_sql'
    privateEndpoint_SubnetID: virtualNetwork.outputs.privateEndpoint_SubnetID
    privateLinkServiceId: sql.outputs.sqlServer_ID
    virtualNetwork_IDs: [virtualNetwork.outputs.virtualNetwork_ID]
  }
}

module clientVM_Windows '../../modules/Microsoft.Compute/WindowsServer2022/VirtualMachine.bicep' = {
  name: 'ClientVM'
  params: {
    acceleratedNetworking: false
    location: location
    subnet_ID: virtualNetwork.outputs.general_SubnetID
    virtualMachine_AdminPassword: virtualMachine_AdminPassword
    virtualMachine_AdminUsername: virtualMachine_AdminUsername
    virtualMachine_Name: 'ClientVM'
    virtualMachine_Size: virtualMachine_Size
    virtualMachine_ScriptFileLocation: virtualMachine_ScriptFileLocation
    virtualMachine_ScriptFileName: 'WinServ2022_ConfigScript_General.ps1'
    commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File WinServ2022_ConfigScript_General.ps1 -Username ${virtualMachine_AdminUsername}'
  }
}

module AzFW '../../modules/Microsoft.Network/AzureFirewall.bicep' = if (isUsingAzureFirewall) {
  name: 'AzFW'
  params: {
    azureFirewall_Name: 'AzFW'
    azureFirewall_SKU: azureFirewall_SKU
    azureFirewall_ManagementSubnet_ID: virtualNetwork.outputs.azureFirewallManagement_SubnetID
    azureFirewallPolicy_Name: 'AzFW_Policy'
    azureFirewall_Subnet_ID: virtualNetwork.outputs.azureFirewall_SubnetID
    location: location
  }
}

module udrToAzFW '../../modules/Microsoft.Network/RouteTable.bicep' = if (isUsingAzureFirewall) {
  name: 'udrToAzFW_Hub'
  params: {
    addressPrefixs: [virtualNetwork.outputs.virtualNetwork_AddressPrefix]
    nextHopType: 'VirtualAppliance'
    routeTable_Name: virtualNetwork.outputs.routeTable_Name
    routeTableRoute_Name: 'toAzFW'
    nextHopIpAddress: AzFW.outputs.azureFirewall_PrivateIPAddress
  }
}

module bastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_name: 'Hub_Bastion'
    bastion_SubnetID: virtualNetwork.outputs.bastion_SubnetID
    location: location
  }
}
