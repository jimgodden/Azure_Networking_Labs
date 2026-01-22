@description('Azure Datacenter location for the Hub and Spoke A resources')
var location = resourceGroup().location

@description('''
Storage account name restrictions:
- Storage account names must be between 3 and 24 characters in length and may contain numbers and lowercase letters only.
- Your storage account name must be unique within Azure. No two storage accounts can have the same name.
''')
@minLength(3)
@maxLength(24)
param storageAccount_Name string

@description('Name of the Key Vault')
param keyVault_Name string

param tagValues object = {
  Training: 'AzureFirewall'
}

resource networkSecurityGroup_Generic 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'genericNSG'
  location: location
  tags: tagValues
}

resource virtualNetwork_Hub 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'hub_VNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'General'
        properties: {
          addressPrefix: '10.0.0.0/24'
          routeTable: {
            id: routeTable_Hub.id
          }
          networkSecurityGroup: {
            id: networkSecurityGroup_Generic.id
          }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          routeTable: {
            id: routeTable_Hub.id
          }
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
        }
      }
    ]
  }
  tags: tagValues
}

resource routeTable_Hub 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'hub_RouteTable'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'toSpokeA'
        properties: {
          addressPrefix: '10.1.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
      {
        name: 'toSpokeB'
        properties: {
          addressPrefix: '10.2.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
    ]
  }
  tags: tagValues
}

resource routeTable_Firewall 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'firewall_RouteTable'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'toInternetFull'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'Internet'
        }
      }
      {
        name: 'toInternetA'
        properties: {
          addressPrefix: '0.0.0.0/1'
          nextHopType: 'VirtualNetworkGateway'
        }
      }
      {
        name: 'toInternetB'
        properties: {
          addressPrefix: '128.0.0.0/1'
          nextHopType: 'VirtualNetworkGateway'
        }
      }
    ]
  }
  tags: tagValues
}

resource virtualNetwork_SpokeA 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'spokeA_VNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'General'
        properties: {
          addressPrefix: '10.1.0.0/24'
          routeTable: {
            id: routeTable_SpokeA.id
          }
          networkSecurityGroup: {
            id: networkSecurityGroup_Generic.id
          }
        }
      }
    ]
  }
  tags: tagValues
}

resource routeTable_SpokeA 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'spokeA_RouteTable'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'toHub'
        properties: {
          addressPrefix: '10.0.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
      {
        name: 'toSpokeB'
        properties: {
          addressPrefix: '10.2.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
      {
        name: 'toOnPrem'
        properties: {
          addressPrefix: '10.100.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
      {
        name: 'toGoogle'
        properties: {
          addressPrefix: '8.8.8.8/32'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
    ]
  }
  tags: tagValues
}

resource virtualNetwork_SpokeB 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'spokeB_VNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.2.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'General'
        properties: {
          addressPrefix: '10.2.0.0/24'
          routeTable: {
            id: routeTable_SpokeB.id
          }
          networkSecurityGroup: {
            id: networkSecurityGroup_Generic.id
          }
        }
      }
      {
        name: 'PrivateEndpoint'
        properties: {
          addressPrefix: '10.2.1.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup_Generic.id
          }
        }
      }
    ]
  }
  tags: tagValues
}

resource routeTable_SpokeB 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'spokeB_RouteTable'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'toHub'
        properties: {
          addressPrefix: '10.0.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
      {
        name: 'toSpokeA'
        properties: {
          addressPrefix: '10.1.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
      {
        name: 'toOnPrem'
        properties: {
          addressPrefix: '10.100.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.2.4'
        }
      }
    ]
  }
  tags: tagValues
}


resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccount_Name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: true
    publicNetworkAccess: 'Enabled'
    allowCrossTenantReplication: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Deny'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: false
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
  tags: tagValues
}
module storageAccount_Blob_PrivateEndpoint '../../../modules/Microsoft.Network/PrivateEndpoint.bicep' = {
  name: 'storageAccount_Blob_PrivateEndpoint'
  params: {
    location: location
    groupID: 'blob'
    privateDNSZone_Name: 'privatelink.blob.${environment().suffixes.storage}'
    privateEndpoint_Name: 'spokeB_${storageAccount_Name}_blob_PrivateEndpoint'
    privateEndpoint_SubnetID: virtualNetwork_SpokeB.properties.subnets[1].id
    privateLinkServiceId: storageAccount.id
    virtualNetwork_IDs: [
      virtualNetwork_Hub.id
      virtualNetwork_SpokeA.id
      virtualNetwork_SpokeB.id
    ]
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: keyVault_Name
  location: location
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
  }
}

module keyVault_PrivateEndpoint '../../../modules/Microsoft.Network/PrivateEndpoint.bicep' = {
  name: 'keyVault_PrivateEndpoint'
  params: {
    location: location
    groupID: 'vault'
    privateDNSZone_Name: 'privatelink.vault.${environment().suffixes.storage}'
    privateEndpoint_Name: 'spokeB_${keyVault_Name}_vault_PrivateEndpoint'
    privateEndpoint_SubnetID: virtualNetwork_SpokeB.properties.subnets[1].id
    privateLinkServiceId: keyVault.id
    virtualNetwork_IDs: [
      virtualNetwork_Hub.id
      virtualNetwork_SpokeA.id
      virtualNetwork_SpokeB.id
    ]
  }
}
