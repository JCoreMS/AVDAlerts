targetScope = 'subscription'

param DeployToSub string
param RoleAssignments object
param PrincipalId string
param LogAnalyticsWorkspaceResourceId string

resource roleAssignment_LAWSub 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(DeployToSub, RoleAssignments.LogAnalyticsContributor.Name)
  properties: {
    principalId: PrincipalId
    roleDefinitionId: resourceId(split(LogAnalyticsWorkspaceResourceId,'/')[2],'Microsoft.Authorization/roleDefinition', RoleAssignments.LogAnalyticsContributor.GUID)
    principalType: 'ServicePrincipal'
  }
}
