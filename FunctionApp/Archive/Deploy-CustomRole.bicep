targetScope = 'subscription'
var dataActions = [
  'Microsoft.Insights/Telemetry/Write'
]
var roleName = 'AVDFunctionApp - Write to Metrics'
var roleDescription = 'This role allows the AVD Function App to write to a Log Analytics Metrics for additional AVD monitoring and alerting.'
var roleDefName_var = guid(subscription().id, string(dataActions))

resource roleDefName 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' = {
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
