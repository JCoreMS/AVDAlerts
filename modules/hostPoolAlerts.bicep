param ActionGroupId string
param HostPoolName string
param LogAlertsHostPool array
param LogAnalyticsWorkspaceResourceId string
param Location string
param Tags object

resource logAlertHostPoolQueries 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = [for i in range(0, length(LogAlertsHostPool)): {
  name: replace(LogAlertsHostPool[i].name, 'xHostPoolNamex', HostPoolName)
  location: Location
  tags: contains(Tags, 'Microsoft.Insights/scheduledQueryRules') ? Tags['Microsoft.Insights/scheduledQueryRules'] : {}

  properties: {
    actions: {
      actionGroups: [
        ActionGroupId
      ]
      customProperties: {}
    }
    criteria: {
      allOf: [
        {
          query: replace(LogAlertsHostPool[i].criteria.allOf[0].query, 'xHostPoolNamex', HostPoolName)
          timeAggregation: LogAlertsHostPool[i].criteria.allOf[0].timeAggregation
          dimensions: LogAlertsHostPool[i].criteria.allOf[0].dimensions
          operator: LogAlertsHostPool[i].criteria.allOf[0].operator
          threshold: LogAlertsHostPool[i].criteria.allOf[0].threshold
          failingPeriods: LogAlertsHostPool[i].criteria.allOf[0].failingPeriods
        }]
    }
    displayName: replace(LogAlertsHostPool[i].displayName, 'xHostPoolNamex', HostPoolName)
    description: replace(LogAlertsHostPool[i].description, 'xHostPoolNamex', HostPoolName)
    enabled: false
    evaluationFrequency: LogAlertsHostPool[i].evaluationFrequency
    scopes: [
      LogAnalyticsWorkspaceResourceId
    ]
    severity: LogAlertsHostPool[i].severity
    windowSize: LogAlertsHostPool[i].windowSize
  }
}]
