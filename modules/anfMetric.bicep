param Location string
param MetricAlertsANF array
param ANFVolumeResourceID string
param ActionGroupID string
param Tags object

resource metricAlerts_ANFVolume 'Microsoft.Insights/metricAlerts@2018-03-01' = [for i in range(0, length(MetricAlertsANF)): {
  name: '${MetricAlertsANF[i].name}-${split(ANFVolumeResourceID, '/')[12]}'
  location: 'global'
  tags: contains(Tags, 'Microsoft.Insights/metricAlerts') ? Tags['Microsoft.Insights/metricAlerts'] : {}
  properties: {
    description: MetricAlertsANF[i].description
    severity: MetricAlertsANF[i].severity
    enabled: false
    scopes: [
      ANFVolumeResourceID
    ]
    evaluationFrequency: MetricAlertsANF[i].evaluationFrequency
    windowSize: MetricAlertsANF[i].windowSize
    criteria: MetricAlertsANF[i].criteria
    autoMitigate: false
    targetResourceType: MetricAlertsANF[i].targetResourceType
    targetResourceRegion: Location
    actions: [
      {
        actionGroupId: ActionGroupID
      }
    ]
  }
}]


