
param LogAnalyticsWorkspaceResourceId string

var LogAnalyticsRG = split(LogAnalyticsWorkspaceResourceId, '/')[4]
var LogAnalyticsWorkspaceName = split(LogAnalyticsWorkspaceResourceId, '/')[8]

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
  scope: resourceGroup(LogAnalyticsRG)
  name: LogAnalyticsWorkspaceName
}
