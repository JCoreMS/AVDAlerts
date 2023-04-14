param Location string
param StorageAccountResourceID string
param MetricAlertsStorageAcct array
param ActionGroupID string
param Tags object

resource metricAlerts_StorageAcct 'Microsoft.Insights/metricAlerts@2018-03-01' = [for i in range(0, length(MetricAlertsStorageAcct)): {
  name: '${MetricAlertsStorageAcct[i].name}-${split(StorageAccountResourceID, '/')[8]}'
  location: 'global'
  tags: contains(Tags, 'Microsoft.Insights/metricAlerts') ? Tags['Microsoft.Insights/metricAlerts'] : {}
  properties: {
    severity: MetricAlertsStorageAcct[i].severity
    enabled: false
    scopes: [
      StorageAccountResourceID
    ]
    evaluationFrequency: MetricAlertsStorageAcct[i].evaluationFrequency
    windowSize: MetricAlertsStorageAcct[i].windowSize
    criteria: MetricAlertsStorageAcct[i].criteria
    autoMitigate: false
    targetResourceType: MetricAlertsStorageAcct[i].targetResourceType
    targetResourceRegion: Location
    actions: [
      {
        actionGroupId: ActionGroupID
      }
    ]
  }
}]


