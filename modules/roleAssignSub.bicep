targetScope = 'subscription'

param AccountName string
param RoleDefinition object
param PrincipalId string
param Subscription string


resource roleAssignment_Subscription 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(Subscription, AccountName, RoleDefinition.name)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', RoleDefinition.GUID)
    principalId: PrincipalId
    principalType: 'ServicePrincipal'
  }
}
