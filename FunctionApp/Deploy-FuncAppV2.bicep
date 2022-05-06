targetScope = 'subscription'

@description('Resource Group to create resources in.')
param ResourceGroupName string

@description('Azure Region for Resources')
param Location string = deployment().location

@description('Log Analytics Workspace to store Metrics data')
param LogAnalyticsWorkSpaceName string

@description('Resource Group with Host Pool "type" Resources (may be different than RG with VMs)')
param HostPoolResourceLocationRG array

var dataActions = [
  'Microsoft.Insights/Telemetry/Write'
]
var roleName = 'AVDFunctionApp - Write to Metrics'
var roleDescription = 'This role allows the AVD Function App to write to a Log Analytics Metrics for additional AVD monitoring and alerting.'
var roleDefName_var = guid(subscription().id, string(dataActions))

resource resourceGroupAlerts 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: ResourceGroupName
  location: Location
}

resource roleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' = {
  name: roleDefName_var
    properties: {
    roleName: roleName
    description: roleDescription
    type: 'customRole'
    permissions: [
      {
        dataActions: dataActions
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

module functionApp 'modules/functionAppV2.bicep' = {
  scope: resourceGroupAlerts
  name: 'FunctionAppDeployment'
  params: {
    Location: Location
    LogAnalyticsWorkspaceName: LogAnalyticsWorkSpaceName
  }
}

resource roleCustomAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(subscription().subscriptionId, functionApp.name, roleDefinition.name)
  properties: {
    principalId: functionApp.outputs.principalID
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleDefinition.id
  }
}

resource roleReaderAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(subscription().subscriptionId, functionApp.name, 'reader')
  properties: {
    principalId: functionApp.outputs.principalID
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7') // Reader
  }
}


