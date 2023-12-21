@description('Azure Datacenter location for the source resources')
param location string = resourceGroup().location

@description('Username for the admin account of the Virtual Machines')
param virtualMachine_AdminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param virtualMachine_AdminPassword string

@description('Size of the Virtual Machines')
param virtualMachine_Size string = 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('Username for the admin account of the SQL Server')
param sql_AdministratorUsername string

@description('Password for the admin account of the SQL Server')
@secure()
param sql_AdministratorPassword string

@description('Name of the SQL Server')
param sqlServer_Name string = 'sql${uniqueString(resourceGroup().id)}'


module sql '../../modules/Microsoft.Sql/Server.bicep' = {
  name: 'sql'
  params: {
    location: location
    sql_AdministratorPassword: sql_AdministratorPassword
    sql_AdministratorUsername: sql_AdministratorUsername
    sqlServer_Name: sqlServer_Name
  }
}

module virtualNetwork '../../modules/Microsoft.Network/VirtualNetworkHub.bicep' = {
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
    fqdn: '${sql.outputs.sqlServer_Name}${environment().suffixes.sqlServerHostname}'
    groupID: 'sqlServer'
    location: location
    privateDNSZone_Name: '${sqlServer_Name}.privatelink${environment().suffixes.sqlServerHostname}'
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
  }
}

module bastion '../../modules/Microsoft.Network/Bastion.bicep' = {
  name: 'bastion'
  params: {
    bastion_SubnetID: virtualNetwork.outputs.bastion_SubnetID
    location: location
  }
}
