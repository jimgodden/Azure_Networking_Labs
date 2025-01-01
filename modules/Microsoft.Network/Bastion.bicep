@description('Azure Datacenter location that the main resouces will be deployed to.')
param location string

@description('Name of the Azure Bastion')
param bastion_name string

@description('Resource ID of the subnet the Azure Bastion will be placed in.  The name of the subnet must be "AzureBastionSubnet"')
param bastion_SubnetID string

param enableTunneling bool = false
param enableIpConnect bool = false
param disableCopyPaste bool = false
param enableShareableLink bool = false
param enableFileCopy bool = false
param enableKerberos bool = false
param enablePrivateOnlyBastion bool = false

@description('SKU of the Azure Bastion')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param bastion_SKU string = 'Basic'

param tagValues object = {}

resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: bastion_name
  location: location
  sku: {
    name: bastion_SKU
  }
  properties: {
    scaleUnits: 2
    enableTunneling: enableTunneling
    enableIpConnect: enableIpConnect
    disableCopyPaste: disableCopyPaste
    enableShareableLink: enableShareableLink
    enableFileCopy: enableFileCopy
    enableKerberos: enableKerberos
    enablePrivateOnlyBastion: enablePrivateOnlyBastion
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: bastion_vip.id
          }
          subnet: {
            id: bastion_SubnetID
          }
        }
      }
    ]
  }
  tags: tagValues
}

resource bastion_vip 'Microsoft.Network/publicIPAddresses@2022-09-01' = {
  name: '${bastion_name}_VIP'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    ipTags: []
  }
  tags: tagValues
}
