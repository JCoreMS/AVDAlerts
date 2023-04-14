targetScope = 'subscription'

param CurrentSub string
param RoleAssignments object
param PrincipalId string

resource roleAssignment_LAWSub 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(CurrentSub, RoleAssignments.DesktopVirtualizationRead.Name)
  properties: {
    principalId: PrincipalId
    roleDefinitionId: resourceId(CurrentSub,'Microsoft.Authorization/roleDefinition', RoleAssignments.DesktopVirtualizationRead.GUID)
    principalType: 'ServicePrincipal'
  }
}
