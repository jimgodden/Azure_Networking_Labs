@description('Region that the resources are deployed to')
param location string

// @description('Name of the Virtual Network for both the Application Gateway and App Service Environment')
// param Vnet_Name string

// @description('Name of the Application Gateway subnet')
// param AppGW_Subnet_Name string

@description('Name of the Application Gateway')
param AppGW_Name string

@description('Name of the Public IP Address resource of the Applciation Gateway')
param AppGW_PIP_Name string

param AppGW_PrivateIP_Address string

param AppGW_SubnetID string

@description('Name of the Web Application Firewall of the Application Gateway')
param AppGW_WAF_Name string

@description('FQDN of the website in the backend pool of the Application Gateway')
param backendPoolFQDN string

// var appGWSubnetID = resourceId('Microsoft.Network/virtualNetworks/subnets', Vnet_Name, AppGW_Subnet_Name)

@description('Application Gateway sub resource IDs')
var frontendID = resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', AppGW_Name, 'fip_private')
var frontendPortID = resourceId('Microsoft.Network/applicationGateways/frontendPorts', AppGW_Name, 'port_80')
var httpListenerID = resourceId('Microsoft.Network/applicationGateways/httpListeners', AppGW_Name, 'http_listener')
var backendAddressPoolID = resourceId('Microsoft.Network/applicationGateways/backendAddressPools', AppGW_Name, 'bep')
var backendHTTPSettingsID = resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', AppGW_Name, 'http-to-asp-settings')


// Done
resource AppGW_WAF 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2022-11-01' = {
  name: AppGW_WAF_Name
  location: location
  properties: {
    customRules: []
    policySettings: {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
      state: 'Enabled'
      mode: 'Detection'
      requestBodyInspectLimitInKB: 128
      fileUploadEnforcement: true
      requestBodyEnforcement: true
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
          ruleGroupOverrides: []
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '0.1'
          ruleGroupOverrides: []
        }
      ]
      exclusions: []
    }
  }
}

//Done
resource AppGW_PIP 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: AppGW_PIP_Name
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
}


resource AppGW 'Microsoft.Network/applicationGateways@2022-11-01' = {
  name: AppGW_Name
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: AppGW_SubnetID
          }
        }
      }
    ]
    sslCertificates: []
    trustedRootCertificates: []
    trustedClientCertificates: []
    sslProfiles: []
    frontendIPConfigurations: [
      {
        name: 'fip_pub'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: AppGW_PIP.id
          }
        }
      }
      {
        name: 'fip_private'
        properties: {
          privateIPAddress: AppGW_PrivateIP_Address
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: AppGW_SubnetID
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'bep'
        properties: {
          backendAddresses: [
            {
              fqdn: backendPoolFQDN
            }
          ]
        }
      }
    ]
    loadDistributionPolicies: []
    backendHttpSettingsCollection: [
      {
        name: 'http-to-asp-settings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'http_listener'
        properties: {
          frontendIPConfiguration: {
            id: frontendID
          }
          frontendPort: {
            id: frontendPortID
          }
          protocol: 'Http'
          hostNames: []
          requireServerNameIndication: false
        }
      }
    ]
    listeners: []
    urlPathMaps: []
    requestRoutingRules: [
      {
        name: 'http-to-asp'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: httpListenerID
          }
          backendAddressPool: {
            id: backendAddressPoolID
          }
          backendHttpSettings: {
            id: backendHTTPSettingsID
          }
        }
      }
    ]
    routingRules: []
    probes: []
    rewriteRuleSets: []
    redirectConfigurations: []
    privateLinkConfigurations: []
    enableHttp2: true
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 2
    }
    firewallPolicy: {
      id: AppGW_WAF.id
    }
  }
}
