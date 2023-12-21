@description('Azure Datacenter location for the source resources')
param location string

@description('Username for the admin account of the SQL Server')
param sql_AdministratorUsername string

@description('Password for the admin account of the SQL Server')
@secure()
param sql_AdministratorPassword string

@description('Name of the SQL Server')
param sqlServer_Name string

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

output sqlServer_ID string = sqlServer.id
output sqlServer_Name string = sqlServer.name
