targetScope = 'resourceGroup'

param AccountName string
param ResourceGroup string
param RoleDefinition object
param PrincipalId string


resource roleAssignment_Subscription 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(subscription().id, AccountName, RoleDefinition.name, ResourceGroup)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', RoleDefinition.GUID)
    principalId: PrincipalId
    principalType: 'ServicePrincipal'
  }
}
