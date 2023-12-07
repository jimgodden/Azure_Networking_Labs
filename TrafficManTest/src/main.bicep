param trafficManagerProfile_Name string = uniqueString(resourceGroup().id)

module trafficManagerProfile '../../modules/Microsoft.Network/TrafficManager.bicep' = {
  name: trafficManagerProfile_Name
  params: {
    trafficManagerProfile_Name: trafficManagerProfile_Name
  }
}
