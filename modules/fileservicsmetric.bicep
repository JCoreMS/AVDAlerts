param Location string
param StorageAccountResourceID string
param MetricAlertsFileShares array
param ActionGroupID string
param Tags object

var FileServicesResourceID = '${StorageAccountResourceID}/fileServices/default'

resource metricAlerts_FileShares 'Microsoft.Insights/metricAlerts@2018-03-01' = [for i in range(0, length(MetricAlertsFileShares)): {
  name: '${MetricAlertsFileShares[i].name}-${split(FileServicesResourceID, '/')[8]}'
  location: 'global'
  tags: contains(Tags, 'Microsoft.Insights/metricAlerts') ? Tags['Microsoft.Insights/metricAlerts'] : {}
  properties: {
    description: MetricAlertsFileShares[i].description
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
