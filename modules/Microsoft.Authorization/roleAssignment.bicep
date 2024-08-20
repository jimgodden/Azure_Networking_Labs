@description('Specifies the role definition ID used in the role assignment.')
param roleDefinitionID string

@description('Specifies the principal ID assigned to the role.')
param principalId string

var roleAssignmentName= guid(principalId, roleDefinitionID, resourceGroup().id)

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentName
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionID)
    principalId: principalId
  }
}

output roleAssignment_name string = roleAssignment.name
output roleAssignment_ResourceGroupName string = resourceGroup().name
output roleAssignment_ID string = roleAssignment.id
