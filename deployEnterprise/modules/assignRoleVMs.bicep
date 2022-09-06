targetScope = 'subscription'

param CurrentSub string
param RoleAssignments object
param PrincipalId string

resource roleAssignment_LAWSub 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(CurrentSub, RoleAssignments.DesktopVirtualizationRead.Name)
  properties: {
    principalId: PrincipalId
    roleDefinitionId: resourceId(CurrentSub,'Microsoft.Authorization/roleDefinition', RoleAssignments.DesktopVirtualizationRead.GUID)
    principalType: 'ServicePrincipal'
  }
}
