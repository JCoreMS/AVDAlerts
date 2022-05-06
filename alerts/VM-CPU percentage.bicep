param metricAlerts_CPU_Percentage_name string = 'CPU Percentage'

resource metricAlerts_CPU_Percentage_name_resource 'microsoft.insights/metricAlerts@2018-03-01' = {
  name: metricAlerts_CPU_Percentage_name
  location: 'global'
  properties: {
    severity: 3
    enabled: true
    scopes: [
      '/subscriptions/9e087dff-9c5b-4650-96ee-19cfe5269c5d/resourceGroups/avd-remoteapp-rg'
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          threshold: 90
          name: 'Metric1'
          metricNamespace: 'microsoft.compute/virtualmachines'
          metricName: 'Percentage CPU'
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'microsoft.compute/virtualmachines'
    targetResourceRegion: 'eastus'
    actions: []
  }
}