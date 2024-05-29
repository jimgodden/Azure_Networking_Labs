@description('Azure Datacenter location that Virtual WAN')
param location string

@description('Name of the Virtual WAN resource')
param virtualWAN_Name string

param tagValues object = {}

resource virtualWAN 'Microsoft.Network/virtualWans@2022-07-01' = {
  name: virtualWAN_Name
  location: location
  properties: {
    disableVpnEncryption: false
    allowBranchToBranchTraffic: true
    type: 'Standard'
  }
  tags: tagValues
}

output virtualWAN_ID string = virtualWAN.id
