// Credit to Dan Wheeler for this module

param ATM_Name string = 'bicep-atm-profile'
 
@allowed([
  'Priority'
  'Weighted'
  'Performance'
  'Geographic'
  'Multivalue'
  'Subnet'
])
param RoutingMethod string = 'Performance'
 
@allowed([
  'HTTP'
  'HTTPS'
  'TCP'
])
param probeProtocol string = 'HTTP'
 
param customPort int = 8080
 
param externalEndpointNames array = [
  'Endpoint1'
  'Endpoint2'
  'Endpoint3'
  'Endpoint4'
]
param endpoint array = [
  'www.contoso.com'
  'www.fabrikam.com'
  'www.adventure-works.com'
  '1.1.1.1'
]
 
param weight array = [
  1
  1
  1
]
 
var location = resourceGroup().location
var port = probeProtocol == 'HTTP' ? 80 : probeProtocol == 'HTTPS' ? 443 : customPort
 
resource ATM 'Microsoft.Network/trafficmanagerprofiles@2022-04-01' = {
  name: ATM_Name
  location: location
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: RoutingMethod
    dnsConfig: {
      relativeName: 'atm'
      ttl: 60
    }
    monitorConfig: {
      protocol: probeProtocol
      port: port
    }
  }
}
 
resource ExternalEndpoint 'Microsoft.Network/trafficmanagerprofiles/externalendpoints@2022-04-01' = [for (endpointName, i) in externalEndpointNames: {
  parent: ATM
  name: endpointName
  properties: {
    target: endpoint[i]
    endpointStatus: 'Enabled'
    weight: weight[i]
  }
}]



// param trafficManagerProfile_Name string

// #disable-next-line no-hardcoded-env-urls
// @description('The relative name in the FQDN for this profile endpoint.  Will be added to the front of ".trafficmanager.net".  Must be unique.')
// param relativeName string

// @description('Descriptive name for the Custom Header.  Not the FQDN.')
// param customHeader_Name string

// @description('Full FQDN of the Custom Header.')
// param customHeader_Value string

// param tagValues object = {}

// resource trafficManagerProfile 'Microsoft.Network/trafficmanagerprofiles@2018-04-01' = {
//   name: trafficManagerProfile_Name
//   location: 'global'
//   properties: {
//     profileStatus: 'Enabled'
//     trafficRoutingMethod: 'Performance'
//     dnsConfig: {
//       relativeName: relativeName
//     }
//     monitorConfig: {
//       profileMonitorStatus: 'Disabled'
//       protocol: 'HTTPS'
//       port: 443
//       path: '/'
//       intervalInSeconds: 30
//       toleratedNumberOfFailures: 3
//       timeoutInSeconds: 10
//       customHeaders: [
//         {
//           name: customHeader_Name
//           value: customHeader_Value
//         }
//       ]
//     }
//   }
//   tags: tagValues
// }
