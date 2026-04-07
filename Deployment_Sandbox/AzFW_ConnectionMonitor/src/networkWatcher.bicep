@description('Azure Datacenter location')
param location string

@description('Resource Id of the source VM (must have Network Watcher extension)')
param sourceVM_ResourceId string

@description('Resource Id of the destination VM (must have Network Watcher extension)')
param destinationVM_ResourceId string

@description('Resource Id of the Log Analytics Workspace')
param workspaceResourceId string

@description('Resource Id of the Storage Account for flow logs')
param storageAccountId string

@description('Resource Id of the VNet for flow logs')
param virtualNetwork_ResourceId string

resource networkWatcher 'Microsoft.Network/networkWatchers@2024-05-01' existing = {
  name: 'NetworkWatcher_${location}'
}

// ---- Connection Monitor: TCP 3389 + HTTPS 443 probes ----
resource connectionMonitor 'Microsoft.Network/networkWatchers/connectionMonitors@2024-05-01' = {
  parent: networkWatcher
  name: 'AzFW-ConnectionMonitor'
  location: location
  properties: {
    endpoints: [
      {
        name: 'sourceVM'
        type: 'AzureVM'
        resourceId: sourceVM_ResourceId
      }
      {
        name: 'destinationVM'
        type: 'AzureVM'
        resourceId: destinationVM_ResourceId
      }
    ]
    testConfigurations: [
      {
        name: 'TCP_3389'
        testFrequencySec: 60
        protocol: 'Tcp'
        tcpConfiguration: {
          port: 3389
          disableTraceRoute: false
        }
        successThreshold: {
          checksFailedPercent: 10
        }
      }
      {
        name: 'HTTPS_443'
        testFrequencySec: 60
        protocol: 'Http'
        httpConfiguration: {
          port: 443
          method: 'Get'
          preferHTTPS: true
          validStatusCodeRanges: [
            '200-404'
          ]
        }
        successThreshold: {
          checksFailedPercent: 10
        }
      }
    ]
    testGroups: [
      {
        name: 'TCP_RDP_TestGroup'
        disable: false
        testConfigurations: [
          'TCP_3389'
        ]
        sources: [
          'sourceVM'
        ]
        destinations: [
          'destinationVM'
        ]
      }
      {
        name: 'HTTPS_TestGroup'
        disable: false
        testConfigurations: [
          'HTTPS_443'
        ]
        sources: [
          'sourceVM'
        ]
        destinations: [
          'destinationVM'
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

// ---- Flow Logs ----
resource networkWatcher_FlowLogs 'Microsoft.Network/networkWatchers/flowLogs@2024-05-01' = {
  parent: networkWatcher
  name: 'vnet-FlowLogs'
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
    storageId: storageAccountId
    retentionPolicy: {
      days: 10
      enabled: true
    }
    targetResourceId: virtualNetwork_ResourceId
    format: {
      type: 'JSON'
    }
  }
}
