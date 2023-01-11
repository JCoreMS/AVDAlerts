targetScope = 'subscription'

param CurrentSub string
param RoleAssignments object
param PrincipalId string

resource roleAssignment_StorAcct 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(CurrentSub, RoleAssignments.StoreAcctContrib.Name)
  properties: {
    principalId: PrincipalId
    roleDefinitionId: resourceId(CurrentSub,'Microsoft.Authorization/roleDefinition', RoleAssignments.StoreAcctContrib.GUID)
    principalType: 'ServicePrincipal'
  }
}
