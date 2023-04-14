param ActivityLogAlerts array
param CloudEnvironment string
param AVDHostSubID string
param Tags object
param ActionGroupID string


// Currently only deploys IF Cloud Environment is Azure Commercial Cloud
resource activityLogAlerts 'Microsoft.Insights/activityLogAlerts@2020-10-01' = [for i in range(0, length(ActivityLogAlerts)): if(CloudEnvironment == 'AzureCloud') {
  name: '${ActivityLogAlerts[i].name}-SubID-${AVDHostSubID}' // Append with SubName or GUID
  location: 'Global'
  tags: Tags
  properties: {
    scopes: [
      '/subscriptions/${AVDHostSubID}'  // Figure out multiple sub IDs
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'ServiceHealth'
        }
        {
          anyOf: ActivityLogAlerts[i].anyof
        }
        {
          field: 'properties.impactedServices[*].ServiceName'
          containsAny: [
            'Windows Virtual Desktop'
          ]
        }
      ]
    }
    actions: {
      actionGroups: [
        {
        actionGroupId: ActionGroupID
        }
      ]
    }
    description: ActivityLogAlerts[i].description
    enabled: false
  }
}]

output currSub string = AVDHostSubID
