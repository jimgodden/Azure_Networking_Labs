@description('Azure Datacenter that the resource is deployed to')
param location string

@description('Resource Id of the Storage Account for storing logs')
param StorageAccount_Id string

@description('Resource Id of the target resource for the flow logs')
param FlowLogs_TargetResourceId string

@description('NSG Flow Logs Version Number (1 or 2).')
param Nsg_FlowLogs_Version int = 1

@description('Resource Id of the LogAnalyticsWorkspace for Advanced Diagnostic data storage.')
param workspaceResourceId string

// @description('Unique Identifier that can be used if running this test multiple times.  This is optional.')
// param uniqueIdentifier string = 'test'

param tagValues object = {}

resource networkWatcher 'Microsoft.Network/networkWatchers@2023-11-01' existing = {
  name: 'NetworkWatcher_${location}'
}

resource networkWatcher_FlowLogs 'Microsoft.Network/networkWatchers/flowLogs@2023-11-01' = {
  parent: networkWatcher
  name: 'networkWatcher-FlowLogs'
  location: location
  properties: {
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: {
        enabled: true
        workspaceResourceId: workspaceResourceId
        trafficAnalyticsInterval: 60
      }
    }
    enabled: true
    storageId: StorageAccount_Id
    retentionPolicy: {
      days: 10
      enabled: true
    }
    targetResourceId: FlowLogs_TargetResourceId
    format: {
      version: Nsg_FlowLogs_Version
      type: 'JSON'
    }
  }
  tags: tagValues
}
