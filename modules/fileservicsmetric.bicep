param Location string
param FileServicesResourceID string
param MetricAlertsFileShares array
param ActionGroupID string
param Tags object



resource metricAlerts_FileShares 'Microsoft.Insights/metricAlerts@2018-03-01' = [for i in range(0, length(MetricAlertsFileShares)): {
  name: '${MetricAlertsFileShares[i].name}-${split(FileServicesResourceID, '/')[8]}'
  location: 'global'
  tags: Tags
  properties: {
    severity: MetricAlertsFileShares[i].severity
    enabled: false
    scopes: [
      FileServicesResourceID
    ]
    evaluationFrequency: MetricAlertsFileShares[i].evaluationFrequency
    windowSize: MetricAlertsFileShares[i].windowSize
    criteria: MetricAlertsFileShares[i].criteria
    autoMitigate: false
    targetResourceType: MetricAlertsFileShares[i].targetResourceType
    targetResourceRegion: Location
    actions: [
      {
        actionGroupId: ActionGroupID
      }
    ]
  }
}]
