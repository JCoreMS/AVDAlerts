param Location string
param ActivityLogAlerts array
param ActionGroupID string
param SubscriptionID string
param Tags object

resource activityLogAlerts 'Microsoft.Insights/activityLogAlerts@2020-10-01' = [for i in range(0, length(ActivityLogAlerts)): {
  name: '${ActivityLogAlerts[i].name}'
  location: 'Global'
  tags: Tags
  properties: {
    description: ActivityLogAlerts[i].description
    severity: ActivityLogAlerts[i].severity
    enabled: false
    scopes: [
      SubscriptionID
    ]
    evaluationFrequency: ActivityLogAlerts[i].evaluationFrequency
    windowSize: ActivityLogAlerts[i].windowSize
    criteria: ActivityLogAlerts[i].criteria
    autoMitigate: false
    targetResourceType: ActivityLogAlerts[i].targetResourceType
    targetResourceRegion: Location
    actions: [
      {
        actionGroupId: ActionGroupID
      }
    ]
  }
}]
