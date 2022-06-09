
param LogAnalyticsWorkspaceResourceId string
param LogAlerts array
param Location string
param ActionGroupID string
param Tags object

var LogAnalyticsRG = split(LogAnalyticsWorkspaceResourceId, '/')[4]
var LogAnalyticsWorkspaceName = split(LogAnalyticsWorkspaceResourceId, '/')[8]

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
  scope: resourceGroup(LogAnalyticsRG)
  name: LogAnalyticsWorkspaceName
}

resource scheduledQueryRules 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = [for i in range(0, length(LogAlerts)): {
  name: LogAlerts[i].name
  location: Location
  tags: Tags
  properties: {
    actions: {
      actionGroups: [
        ActionGroupID
      ]
      customProperties: {}
    }
    criteria: LogAlerts[i].criteria
    displayName: LogAlerts[i].displayName
    enabled: false
    evaluationFrequency: LogAlerts[i].evaluationFrequency
    scopes: [
      logAnalyticsWorkspace.id
    ]
    severity: LogAlerts[i].severity
    windowSize: LogAlerts[i].windowSize
  }
}]
