@description('Azure Datacenter that the resource is deployed to')
param location string

@description('Resource Id of the Storage Account for storing logs')
param StorageAccount_Id string

@description('Resource Id of the target resource for the flow logs')
param FlowLogs_TargetResourceId string

@description('Resource Id of a Virtual Machine to use as a source Endpoint.  Must have the Network Watcher extension installed.')
param srcEndpointVmResource_Id string

@description('Resource Id of the LogAnalyticsWorkspace for Advanced Diagnostic data storage.')
param workspaceResourceId string

// @description('Unique Identifier that can be used if running this test multiple times.  This is optional.')
// param uniqueIdentifier string = 'test'

resource networkWatcher 'Microsoft.Network/networkWatchers@2023-11-01' existing = {
  name: 'NetworkWatcher_${location}'
}

resource networkWatcher_ConnMon 'Microsoft.Network/networkWatchers/connectionMonitors@2023-11-01' = {
  parent: networkWatcher
  name: 'ConnectionMonitor'
  location: location
  properties: {
    endpoints: [
      {
        name: '${last(split(srcEndpointVmResource_Id, '/'))}(${split(srcEndpointVmResource_Id, '/')[3]})'
        type: 'AzureVM'
        resourceId: srcEndpointVmResource_Id
      }
      {
        name: '8.8.8.8'
        type: 'ExternalAddress'
        address: '8.8.8.8'
      }
    ]
    testConfigurations: [
      {
        name: 'testconfig'
        testFrequencySec: 60
        protocol: 'Tcp'
        tcpConfiguration: {
          port: 53
          disableTraceRoute: false
        }
        successThreshold: {
          checksFailedPercent: 10
        }
      }
    ]
    testGroups: [
      {
        name: 'testgroup'
        disable: false
        testConfigurations: [
          'testconfig'
        ]
        sources: [
          '${last(split(srcEndpointVmResource_Id, '/'))}(${split(srcEndpointVmResource_Id, '/')[3]})'
        ]
        destinations: [
          '8.8.8.8'
        ]
      }
    ]
    outputs: [
      {
        type: 'Workspace'
        workspaceSettings: {
          workspaceResourceId: workspaceResourceId
        }
      }
    ]
  }
}

resource networkWatcher_FlowLogs 'Microsoft.Network/networkWatchers/flowLogs@2023-11-01' = {
  parent: networkWatcher
  name: 'networkWatcher-FlowLogs'
  location: location
  properties: {
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: {
        enabled: true
        // workspaceId: workspaceResourceId
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
      type: 'JSON'
    }
  }
}
