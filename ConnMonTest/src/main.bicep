
@description('Generated from /subscriptions/1a283126-08f5-4fff-8784-19fe92c7422e/resourceGroups/networkwatcherrg/providers/Microsoft.Network/networkWatchers/NetworkWatcher_eastus2/connectionMonitors/portalconnmon')
resource bicepconnmon 'Microsoft.Network/networkWatchers/connectionMonitors@2023-11-01' = {
  name: 'NetworkWatcher_eastus2/bicepconnmon'
  properties: {
    endpoints: [
      {
        name: 'winVM(Azure_VM_Windows_Sandbox_16)'
        type: 'AzureVM'
        resourceId: '/subscriptions/1a283126-08f5-4fff-8784-19fe92c7422e/resourceGroups/Azure_VM_Windows_Sandbox_16/providers/Microsoft.Compute/virtualMachines/winVM'
      }
      {
        name: '8.8.8.8'
        type: 'ExternalAddress'
        address: '8.8.8.8'
      }
    ]
    testConfigurations: [
      {
        name: 'biceptestconfig'
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
        name: 'biceptestgroup'
        disable: false
        testConfigurations: [
          'biceptestconfig'
        ]
        sources: [
          'winVM(Azure_VM_Windows_Sandbox_16)'
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
          workspaceResourceId: '/subscriptions/1a283126-08f5-4fff-8784-19fe92c7422e/resourceGroups/DefaultResourceGroup-EUS2/providers/Microsoft.OperationalInsights/workspaces/DefaultWorkspace-1a283126-08f5-4fff-8784-19fe92c7422e-EUS2'
        }
      }
    ]
  }
  location: 'eastus2'
}
