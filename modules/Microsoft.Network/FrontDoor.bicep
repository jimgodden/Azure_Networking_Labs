
@description('Generated from /subscriptions/1a283126-08f5-4fff-8784-19fe92c7422e/resourceGroups/Sandbox-ApplicationGateway_v2_RG_20/providers/Microsoft.Cdn/profiles/afdtest')
resource afdtest 'Microsoft.Cdn/profiles@2024-05-01-preview' = {
  name: 'afdtest'
  location: 'Global'
  kind: 'frontdoor'
  tags: {}
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    originResponseTimeoutSeconds: 60
    logScrubbing: null
    frontDoorId: 'd3e0f0dd-71c1-4cfe-9e6f-52bef3ea08a2'
    extendedProperties: {}
    resourceState: 'Active'
    provisioningState: 'Succeeded'
  }
}
