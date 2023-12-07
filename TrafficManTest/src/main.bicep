param trafficManagerProfile_Name string = 'trafficManagerProfile_CustomHeaderTest'

param relativeName string = 'testfqdn${uniqueString(resourceGroup().id)}'

module trafficManagerProfile '../../modules/Microsoft.Network/TrafficManager.bicep' = {
  name: trafficManagerProfile_Name
  params: {
    trafficManagerProfile_Name: trafficManagerProfile_Name
    relativeName: relativeName
    customHeader_Name: 'test'
    customHeader_Value: '${relativeName}.com'
  }
}
