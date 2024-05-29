@description('Location that the resources will be deployed to.')
param location string

@description('Name of the Log Analytics Workspace.')
param Workspaces_name string

param tagValues object = {}

resource LogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: Workspaces_name
  location: location
  // identity: {
  //   type: 'string'
  //   userAssignedIdentities: {}
  // }
  // properties: {
  //   defaultDataCollectionRuleResourceId: 'string'
  //   features: {
  //     clusterResourceId: 'string'
  //     disableLocalAuth: bool
  //     enableDataExport: bool
  //     enableLogAccessUsingOnlyResourcePermissions: bool
  //     immediatePurgeDataOn30Days: bool
  //   }
  //   forceCmkForQuery: bool
  //   publicNetworkAccessForIngestion: 'string'
  //   publicNetworkAccessForQuery: 'string'
  //   retentionInDays: int
  //   sku: {
  //     capacityReservationLevel: int
  //     name: 'string'
  //   }
  //   workspaceCapping: {
  //     dailyQuotaGb: int
  //   }
  // }
  tags: tagValues
}

output LogAnalyticsWorkspace_Name string = LogAnalyticsWorkspace.name
output LogAnalyticsWorkspace_ID string = LogAnalyticsWorkspace.id
