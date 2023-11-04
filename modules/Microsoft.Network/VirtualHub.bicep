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

@description('Name of the Azure Firewall within the virtualHub A')
param azureFirewall_Name string = '${virtualHub_Name}_AzFW'

@description('Sku name of the Azure Firewall.  Allowed values are Basic, Standard, and Premium')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param azureFirewall_SKU string = 'Basic'

@description('Name of the Azure Firewall Policy')
param azureFirewallPolicy_Name string = '${virtualHub_Name}_AzFWPolicy'

@description('Deploys a VPN Gateway to the Virtual Hub if true')
param usingVPN bool

@description('Name of the Azure Virtual Network Gateway in the virtualHub')
param vpnGateway_Name string = '${virtualHub_Name}_vpnGateway'





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
  name: vpnGateway_Name
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
}

resource azureFirewall_Policy 'Microsoft.Network/firewallPolicies@2022-07-01' = if (usingAzureFirewall) {
  name: azureFirewallPolicy_Name
  location: location
  properties: {
    sku: {
      tier: azureFirewall_SKU
    }
  }
}

resource azureFirewall 'Microsoft.Network/azureFirewalls@2022-07-01' = if (usingAzureFirewall) {
  name: azureFirewall_Name
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
}


output virtualHub_Name string = virtualHub.name
output virtualHub_RouteTable_Default_ID string = virtualHub_RouteTable_Default.id
