@description('Name of the User Assigned Identity')
param userAssignedIdentity_Name string

@description('Specifies the role definition ID used in the role assignment.')
param roleDefinitionID string

@description('Location that the User Assigned Identity will be deployed to')
param location string

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: userAssignedIdentity_Name
  location: location
}


output userAssignedIdentity_ClientId string = userAssignedIdentity.properties.clientId
output userAssignedIdentity_PrincipalId string = userAssignedIdentity.properties.principalId
output userAssignedIdentity_TenantId string = userAssignedIdentity.properties.tenantId
