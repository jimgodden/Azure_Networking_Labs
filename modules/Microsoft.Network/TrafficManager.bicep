
param trafficManagerProfile_Name string = uniqueString(resourceGroup().id) 


resource trafficManagerProfile 'Microsoft.Network/trafficmanagerprofiles@2018-04-01' = {
  name: trafficManagerProfile_Name
  location: 'global'
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Performance'
    dnsConfig: {
      relativeName: 'anything'
    }
    monitorConfig: {
      profileMonitorStatus: 'Disabled'
      protocol: 'HTTPS'
      port: 443
      path: '/healthcheck.html'
      intervalInSeconds: 30
      toleratedNumberOfFailures: 3
      timeoutInSeconds: 10
      customHeaders: [
        {
          name: 'test'
          value: 'test.anythingidk.com'
        }
      ]
    }
  }
}
