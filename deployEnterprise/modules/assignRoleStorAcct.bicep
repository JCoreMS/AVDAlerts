targetScope = 'subscription'

param CurrentSub string
param RoleAssignments object
param PrincipalId string

resource roleAssignment_StorAcct 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(CurrentSub, RoleAssignments.StoreKeyRead.Name)
  properties: {
    principalId: PrincipalId
    roleDefinitionId: resourceId(CurrentSub,'Microsoft.Authorization/roleDefinition', RoleAssignments.StoreKeyRead.GUID)
    principalType: 'ServicePrincipal'
  }
}
