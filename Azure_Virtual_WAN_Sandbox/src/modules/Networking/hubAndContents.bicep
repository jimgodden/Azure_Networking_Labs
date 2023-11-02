@description('Azure Datacenter location that the main resouces will be deployed to.')
param location string

@description('ID of the existing VWAN')
param vwanID string

@description('Current vHub Iteration')
@minValue(1)
@maxValue(9)
param vHub_Iteration int

// vHub A
@description('Name of the first Virtual Hub within the Virtual WAN')
param vHub_Name string = 'vhub${vHub_Iteration}'

@description('Address Prefix of the first Virtual Hub')
param vHub_AddressPrefix string = '10.${vHub_Iteration}0.0.0/16'

@description('Deploys a Az FW if true')
param usingAzFW bool = true

@description('Name of the Azure Firewall within the vHub A')
param AzFW_Name string = 'AzFW${vHub_Iteration}'

@description('Sku name of the Azure Firewall.  Allowed values are Basic, Standard, and Premium')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param AzFW_SKU string = 'Basic'

@description('Name of the Azure Firewall Policy')
param AzFWPolicy_Name string = 'AzFW_Policy${vHub_Iteration}'

@description('Deploys a S2S VPN if true')
param usingVPN bool

@description('Name of the Azure Virtual Network Gateway in vHub A')
param AzureVNG_Name string = 'vng${vHub_Iteration}'

// @description('VPN Shared Key used for authenticating VPN connections')
// @secure()
// param vpn_SharedKey string

// @description('Name of the Destination VPN Site')
// param destinationVPN_Name string = 'MainVPNSite'

// @description('Public IP Address of the Destination VPN Site')
// param destinationVPN_PublicAddress string = '20.12.2.155'

// @description('BGP Address of the Destination VPN Site')
// param destinationVPN_BGPAddress string = '10.100.0.126'

// @description('Autonomous System Number (ASN) of the Destination VPN Site')
// param destinationVPN_ASN int = 65516

// VNET Start
@description('Current Virtual Network Iteration')
@minValue(1)
@maxValue(9)
param vnet_Iteration int = 1

@description('Name of the Virtual Network')
param vnet_Name string = 'vnet_${vHub_Iteration}_${vnet_Iteration}'

@description('Address Prefix of the Virtual Network')
param vnet_AddressPrefix string = '10.${vHub_Iteration}${vnet_Iteration}.0.0/16'

@description('Name of the Virtual Network')
param subnet_Name string = 'subnet${vnet_Iteration}'

@description('Address Prefix of the Subnet')
param subnet_AddressPrefix string = '10.${vHub_Iteration}${vnet_Iteration}.0.0/24'

@description('Name of the Network Security Group')
param defaultNSG_Name string = 'Default_NSG${vHub_Iteration}'

@description('Name of the Route Table')
param routeTable_Name string = 'General_RouteTable_vhub_${vHub_Iteration}'

@description('Name of the Virtual Machine')
param vm_Name string = 'NetTestVM${vHub_Iteration}'

@description('Admin Username for the Virtual Machine')
param vm_AdminUserName string

@description('Password for the Virtual Machine Admin User')
@secure()
param vm_AdminPassword string

@description('Name of the Virtual Machines Network Interface')
param nic_Name string = '${vm_Name}_nic1'

resource vHub 'Microsoft.Network/virtualHubs@2022-07-01' = {
  name: vHub_Name
  location: location
  properties: {
    addressPrefix: vHub_AddressPrefix
    virtualWan: {
      id: vwanID
    }
    allowBranchToBranchTraffic: false
    hubRoutingPreference: 'VpnGateway'
  }
}


resource vHub_RouteTable_Default 'Microsoft.Network/virtualHubs/hubRouteTables@2022-07-01' = {
  parent: vHub
  name: 'defaultRouteTable'
  properties: {
    routes: []
    labels: [
      'default'
    ]
  }
}

resource vHub_RouteTable_None 'Microsoft.Network/virtualHubs/hubRouteTables@2022-07-01' = {
  parent: vHub
  name: 'noneRouteTable'
  properties: {
    routes: []
    labels: [
      'none'
    ]
  }
}

resource AzureVNG 'Microsoft.Network/vpnGateways@2022-07-01' = if (usingVPN) {
  name: AzureVNG_Name
  location: location
  properties: {
    connections: []
    virtualHub: {
      id: vHub.id
    }
    vpnGatewayScaleUnit: 1
    natRules: []
    enableBgpRouteTranslationForNat: false
    isRoutingPreferenceInternet: false
  }
}

resource AzFW_Policy 'Microsoft.Network/firewallPolicies@2022-07-01' = if (usingAzFW) {
  name: AzFWPolicy_Name
  location: location
  properties: {
    sku: {
      tier: AzFW_SKU
    }
  }
}

resource AzFW 'Microsoft.Network/azureFirewalls@2022-07-01' = if (usingAzFW) {
  name: AzFW_Name
  location: location
  properties: {
    sku: {
      name: 'AzFW_Hub'
      tier: AzFW_SKU
    }
    additionalProperties: {}
    virtualHub: {
      id: vHub.id
    }
    hubIPAddresses: {
      publicIPs: {
        count: 1
      }
    }
    firewallPolicy: {
      id: AzFW_Policy.id
    }
  }
}

module vnet1 'VirtualNetworkSpoke.bicep' = {
  name: 'vnet${vHub_Iteration}'
  params: {
    defaultNSG_Name: defaultNSG_Name
    location: location
    routeTable_Name: routeTable_Name
    subnet_General_AddressPrefix: subnet_AddressPrefix
    subnet_General_Name: subnet_Name
    vnet_AddressPrefix: vnet_AddressPrefix
    vnet_Name: vnet_Name
  }
}

module vm1 '../Compute/NetTestVM.bicep' = {
  name: 'NetTestVM${vHub_Iteration}'
  params: {
    location: location
    nic_Name: nic_Name
    subnetID: vnet1.outputs.generalSubnetID
    vm_AdminPassword: vm_AdminPassword
    vm_AdminUserName: vm_AdminUserName
    vm_Name: vm_Name
  }
}

// Values for connecting the vHub to a Virtual Network
output vHubName string = vHub.name
output vHubRouteTableDefaultID string = vHub_RouteTable_Default.id
output vnetID1 string = vnet1.outputs.vnetResourceID
output vnetName1 string = vnet1.outputs.vnetName
output vpnName string = AzureVNG.name

// values for destination Local Network Gateway
output vpnPubIP0 string = usingVPN ? AzureVNG.properties.bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0] : ''
output vpnPubIP1 string = usingVPN ? AzureVNG.properties.bgpSettings.bgpPeeringAddresses[1].tunnelIpAddresses[0] : ''
output vpnBGPIP0 string = usingVPN ? AzureVNG.properties.bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0] : ''
output vpnBGPIP1 string = usingVPN ? AzureVNG.properties.bgpSettings.bgpPeeringAddresses[1].defaultBgpIpAddresses[0] : ''
