@description('Azure Datacenter that the resource is deployed to')
param location string

@description('Resource Id of the Storage Account for storing logs')
param StorageAccount_Id string

// @description('Name of the NSG Flow Log')
// param FlowLogs_Name string

@description('Resource Id of the target resource for the flow logs')
param FlowLogs_TargetResourceId string

@description('NSG Flow Logs Version Number (1 or 2).')
param FlowLogs_Version int = 2

@description('Resource Id of the LogAnalyticsWorkspace for Advanced Diagnostic data storage.')
param workspaceResourceId string

param tagValues object = {}

var FlowLogs_TargetID_Split = split(FlowLogs_TargetResourceId, '/')
var FlowLogs_Target_Name = FlowLogs_TargetID_Split[8]
var FlowLogs_Target_ResourceGroup = FlowLogs_TargetID_Split[4]

resource networkWatcher 'Microsoft.Network/networkWatchers@2023-11-01' existing = {
  name: 'NetworkWatcher_${location}'
}

resource networkWatcher_FlowLogs 'Microsoft.Network/networkWatchers/flowLogs@2023-11-01' = {
  parent: networkWatcher
  name: '${FlowLogs_Target_ResourceGroup}_${FlowLogs_Target_Name}_Flowlog'
  location: location
  properties: {
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: {
        enabled: true
        workspaceResourceId: workspaceResourceId
        trafficAnalyticsInterval: 10
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
      version: FlowLogs_Version
      type: 'JSON'
    }
  }
  tags: tagValues
}
