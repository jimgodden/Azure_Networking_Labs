
param trafficManagerProfile_Name string

#disable-next-line no-hardcoded-env-urls
@description('The relative name in the FQDN for this profile endpoint.  Will be added to the front of ".trafficmanager.net".  Must be unique.')
param relativeName string

@description('Descriptive name for the Custom Header.  Not the FQDN.')
param customHeader_Name string

@description('Full FQDN of the Custom Header.')
param customHeader_Value string




resource trafficManagerProfile 'Microsoft.Network/trafficmanagerprofiles@2018-04-01' = {
  name: trafficManagerProfile_Name
  location: 'global'
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: 'Performance'
    dnsConfig: {
      relativeName: relativeName
    }
    monitorConfig: {
      profileMonitorStatus: 'Disabled'
      protocol: 'HTTPS'
      port: 443
      path: '/'
      intervalInSeconds: 30
      toleratedNumberOfFailures: 3
      timeoutInSeconds: 10
      customHeaders: [
        {
          name: customHeader_Name
          value: customHeader_Value
        }
      ]
    }
  }
}




















