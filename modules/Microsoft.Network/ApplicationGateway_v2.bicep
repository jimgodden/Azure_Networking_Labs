@description('Region that the resources are deployed to')
param location string

@description('Name of the Application Gateway')
param applicationGateway_Name string

@description('Name of the Public IP Address resource of the Applciation Gateway')
param publicIP_ApplicationGateway_Name string = '${applicationGateway_Name}_PIP'

@description('Name of the Private IP Address of the Frontend of the Applciation Gateway')
param applicationGateway_PrivateIPAddress string

param applicationGateway_SubnetID string

@description('Name of the Web Application Firewall of the Application Gateway')
param applicationGatewayWAF_Name string = '${applicationGateway_Name}_WAF'

@description('FQDN of the website in the backend pool of the Application Gateway')
param backendPoolFQDNs array

param tagValues object = {}

@description('Application Gateway sub resource IDs')
var frontendID = resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGateway_Name, 'fip_private')
var frontendPortID = resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGateway_Name, 'port_80')
var httpListenerID = resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGateway_Name, 'http_listener')
var backendAddressPoolID = resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGateway_Name, 'bep')
var backendHTTPSettingsID = resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGateway_Name, 'http-to-asp-settings')


resource applicationGatewayWAF 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2022-11-01' = {
  name: applicationGatewayWAF_Name
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
  tags: tagValues
}

resource publicIP_ApplicationGateway 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: publicIP_ApplicationGateway_Name
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

resource applicationGateway 'Microsoft.Network/applicationGateways@2022-11-01' = {
  name: applicationGateway_Name
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
            id: applicationGateway_SubnetID
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
            id: publicIP_ApplicationGateway.id
          }
        }
      }
      {
        name: 'fip_private'
        properties: {
          privateIPAddress: applicationGateway_PrivateIPAddress
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: applicationGateway_SubnetID
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
          backendAddresses: [ for backendPoolFQDN in backendPoolFQDNs: {
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
      id: applicationGatewayWAF.id
    }
  }
  tags: tagValues
}

output ApplicationGateway_FrontendIP_Private string = applicationGateway_PrivateIPAddress
