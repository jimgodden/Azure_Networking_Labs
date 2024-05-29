@description('Azure Datacenter location that the main resouces will be deployed to.')
param location string

@description('ID of the existing virtualWAN')
param virtualWAN_ID string

@description('Name of the Virtual Hub')
param virtualHub_Name string

@description('''Address Prefix of the first Virtual Hub
Example: 10.0.0.0/16''')
param virtualHub_AddressPrefix string

@description('Deploys a Azure Firewall to the Virtual Hub if true')
param usingAzureFirewall bool

@description('Sku name of the Azure Firewall.  Allowed values are Basic, Standard, and Premium')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param azureFirewall_SKU string = 'Basic'

@description('Deploys a VPN Gateway to the Virtual Hub if true')
param usingVPN bool

param tagValues object = {}

resource virtualHub 'Microsoft.Network/virtualHubs@2022-07-01' = {
  name: virtualHub_Name
  location: location
  properties: {
    addressPrefix: virtualHub_AddressPrefix
    virtualWan: {
      id: virtualWAN_ID
    }
    allowBranchToBranchTraffic: false
    hubRoutingPreference: 'VpnGateway'
  }
  tags: tagValues
}

resource virtualHub_RouteTable_Default 'Microsoft.Network/virtualHubs/hubRouteTables@2022-07-01' = {
  parent: virtualHub
  name: 'defaultRouteTable'
  properties: {
    routes: []
    labels: [
      'default'
    ]
  }
}

resource virtualHub_RouteTable_None 'Microsoft.Network/virtualHubs/hubRouteTables@2022-07-01' = {
  parent: virtualHub
  name: 'noneRouteTable'
  properties: {
    routes: []
    labels: [
      'none'
    ]
  }
}

resource vpnGateway 'Microsoft.Network/vpnGateways@2022-07-01' = if (usingVPN) {
  name: '${virtualHub_Name}_vpnGateway'
  location: location
  properties: {
    connections: []
    virtualHub: {
      id: virtualHub.id
    }
    vpnGatewayScaleUnit: 1
    natRules: []
    enableBgpRouteTranslationForNat: false
    isRoutingPreferenceInternet: false
  }
  tags: tagValues
}

resource azureFirewall_Policy 'Microsoft.Network/firewallPolicies@2022-07-01' = if (usingAzureFirewall) {
  name: '${virtualHub_Name}_AzFWPolicy'
  location: location
  properties: {
    sku: {
      tier: azureFirewall_SKU
    }
  }
  tags: tagValues
}

resource azureFirewall 'Microsoft.Network/azureFirewalls@2022-07-01' = if (usingAzureFirewall) {
  name: '${virtualHub_Name}_AzFW'
  location: location
  properties: {
    sku: {
      name: 'AzFW_Hub'
      tier: azureFirewall_SKU
    }
    additionalProperties: {}
    virtualHub: {
      id: virtualHub.id
    }
    hubIPAddresses: {
      publicIPs: {
        count: 1
      }
    }
    firewallPolicy: {
      id: azureFirewall_Policy.id
    }
  }
  tags: tagValues
}


output virtualHub_Name string = virtualHub.name
output virtualHub_RouteTable_Default_ID string = virtualHub_RouteTable_Default.id
output vpnGateway_Name string = vpnGateway.name

// values for destination Local Network Gateway stored as Arrays.  
// Each member of an array corresponds to one of the VPN Gateway instances.
var vpnGateway_Name_Array = [vpnGateway.name, vpnGateway.name]
var vpnGateway_PublicIPAddresses = [vpnGateway.properties.bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0],vpnGateway.properties.bgpSettings.bgpPeeringAddresses[1].tunnelIpAddresses[0]]
var vpnGateway_BGPAddresses = [vpnGateway.properties.bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0],vpnGateway.properties.bgpSettings.bgpPeeringAddresses[1].defaultBgpIpAddresses[0]]
var vpnGateway_ASN = [vpnGateway.properties.bgpSettings.asn, vpnGateway.properties.bgpSettings.asn]

output vpnGateway_Name_Array array = usingVPN ? vpnGateway_Name_Array : []
output vpnGateway_PublicIPAddresses array = usingVPN ? vpnGateway_PublicIPAddresses : []
output vpnGateway_BGPAddresses array = usingVPN ? vpnGateway_BGPAddresses : []
output vpnGateway_ASN array = usingVPN ? vpnGateway_ASN : []
