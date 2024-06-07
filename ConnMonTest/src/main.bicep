param srcEndpointVmResource_Id string

param uniqueIdentifier string

resource connmon 'Microsoft.Network/networkWatchers/connectionMonitors@2023-11-01' = {
  name: 'NetworkWatcher_eastus2/${uniqueIdentifier}connmon'
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
        name: '${uniqueIdentifier}testconfig'
        testFrequencySec: 60
        protocol: 'Tcp'
        tcpConfiguration: {
          port: 3389
          disableTraceRoute: false
        }
        // This is missing from the customer's TF deployment
        // successThreshold: {
        //   checksFailedPercent: 10
        // }
      }
    ]
    testGroups: [
      {
        name: '${uniqueIdentifier}testgroup'
        disable: false
        testConfigurations: [
          '${uniqueIdentifier}testconfig'
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
        // workspaceSettings: {
        //   workspaceResourceId: '/subscriptions/1a283126-08f5-4fff-8784-19fe92c7422e/resourceGroups/DefaultResourceGroup-EUS2/providers/Microsoft.OperationalInsights/workspaces/DefaultWorkspace-1a283126-08f5-4fff-8784-19fe92c7422e-EUS2'
        // }
      }
    ]
  }
  location: 'eastus2'
}
