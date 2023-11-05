@description('Azure Datacenter location that the main resouces will be deployed to.')
param location string

@description('Name of the Virtual WAN resource')
param VWAN_Name string

resource VWAN 'Microsoft.Network/virtualWans@2022-07-01' = {
  name: VWAN_Name
  location: location
  properties: {
    disableVpnEncryption: false
    allowBranchToBranchTraffic: true
    type: 'Standard'
  }
}

output vwanID string = VWAN.id
