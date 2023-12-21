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

resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServer_Name
  location: location
  properties: {
    administratorLogin: sql_AdministratorUsername
    administratorLoginPassword: sql_AdministratorPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    restrictOutboundNetworkAccess: 'Disabled'
  }
}

// resource Microsoft_Sql_servers_connectionPolicies_servers_jamesgtestdb_name_default 'Microsoft.Sql/servers/connectionPolicies@2023-05-01-preview' = {
//   parent: servers_jamesgtestdb_name_resource
//   name: 'default'
//   properties: {
//     connectionType: 'Default'
//   }
// }

resource sqlServer_Database 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: 'testdbname'
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Local'
    isLedgerOn: false
    availabilityZone: 'NoPreference'
  }
}

// resource servers_jamesgtestdb_name_current 'Microsoft.Sql/servers/encryptionProtector@2023-05-01-preview' = {
//   parent: sqlServer
//   name: 'current'
//   properties: {
//     serverKeyName: 'ServiceManaged'
//     serverKeyType: 'ServiceManaged'
//     autoRotationEnabled: false
//   }
// }

// resource servers_jamesgtestdb_name_ServiceManaged 'Microsoft.Sql/servers/keys@2023-05-01-preview' = {
//   parent: sqlServer
//   name: 'ServiceManaged'
//   properties: {
//     serverKeyType: 'ServiceManaged'
//   }
// }

// resource servers_jamesgtestdb_name_sqldb_pe_b37a904c_9aa6_4900_97e5_12c513880823 'Microsoft.Sql/servers/privateEndpointConnections@2023-05-01-preview' = {
//   parent: servers_jamesgtestdb_name_resource
//   name: 'sqldb_pe-b37a904c-9aa6-4900-97e5-12c513880823'
//   properties: {
//     privateEndpoint: {
//       id: privateEndpoints_sqldb_pe_externalid
//     }
//     privateLinkServiceConnectionState: {
//       status: 'Approved'
//       description: 'Auto-approved'
//     }
//   }
// }

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
    fqdn: '${sqlServer_Name}${environment().suffixes.sqlServerHostname}'
    groupID: 'sqlServer'
    location: location
    privateDNSZone_Name: '${sqlServer_Name}.privatelink${environment().suffixes.sqlServerHostname}'
    privateEndpoint_Name: 'pe_sql'
    privateEndpoint_SubnetID: virtualNetwork.outputs.privateEndpoint_SubnetID
    privateLinkServiceId: sqlServer.id
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
