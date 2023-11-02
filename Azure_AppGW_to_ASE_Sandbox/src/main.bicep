param location string = resourceGroup().location

@description('Name of the App Service')
param Website_Name string =  'jamesgsite${substring(uniqueString(resourceGroup().id), 0, 5)}'

@description('Username for the admin account of the Virtual Machines')
param vm_adminUsername string

@description('Password for the admin account of the Virtual Machines')
@secure()
param vm_adminPassword string

@description('Password for the Virtual Machine Admin User')
param vmSize string = 'Standard_B2ms' // 'Standard_D2s_v3' // 'Standard_D16lds_v5'

@description('''True enables Accelerated Networking and False disabled it.  
Not all VM sizes support Accel Net (i.e. Standard_B2ms).  
I'd recommend Standard_D2s_v3 for a cheap VM that supports Accel Net.
''')
param accelNet bool = false

module network './modules/Network/VirtualNetwork.bicep' = {
  name: 'vnet'
  params: {
    defaultNSG_Name: 'nsg'
    firstTwoOctetsOfVNETPrefix: '10.0'
    location: location
    routeTable_Name: 'rt'
    vnet_Name: 'vnet'
  }
}

module site './modules/site/site.bicep' = {
  name: 'site'
  params: {
    ASP_Name: 'asp'
    location: location
    Vnet_Name: network.outputs.vnetName
    appServiceSubnetID: network.outputs.appServiceSubnetID
    Website_Name: Website_Name
  }
}

module AppGW './modules/Network/ApplicationGateway.bicep' = {
  name: 'AppGW'
  params: {
    AppGW_Name: 'AppGWv2'
    AppGW_PIP_Name: 'AppGW_PIP'
    AppGW_PrivateIP_Address: network.outputs.applicationGatewayPrivateIP
    AppGW_WAF_Name: 'AppGW_WAF'
    location: location
    AppGW_SubnetID: network.outputs.applicationGatewaySubnetID
    backendPoolFQDN: site.outputs.websiteFQDN
  }
}

// Windows Virtual Machines
module clientVMWindows './Modules/Compute/NetTestVM.bicep' = {
  name: 'clientVMWindows'
  params: {
    accelNet: accelNet
    location: location
    nic_Name: 'clientVMWindows_NIC'
    subnetID: network.outputs.generalSubnetID
    vm_AdminPassword: vm_adminPassword
    vm_AdminUserName: vm_adminUsername
    vm_Name: 'clientVMWindows'
    vmSize: vmSize
  }
}


module hubBastion 'modules/Network/Bastion.bicep' = {
  name: 'hubBastion'
  params: {
    bastionSubnetID: network.outputs.bastionSubnetID
    location: location
  }
}
