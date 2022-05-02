targetScope = 'subscription'

@description('Resource Group to create resources in.')
param ResourceGroupName string

@description('Azure Region for Resources')
param Location string = deployment().location

var dataActions = [
  'Microsoft.Insights/Telemetry/Write'
]
var roleName = 'AVDFunctionApp - Write to Metrics'
var roleDescription = 'This role allows the AVD Function App to write to a Log Analytics Metrics for additional AVD monitoring and alerting.'
var roleDefName_var = guid(subscription().id, string(dataActions))

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
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

module functionApp 'modules/functionApp.bicep' = {
  scope: resourceGroup
  name: 'FunctionAppDeployment'
  params: {
    Location: Location
  }
}
