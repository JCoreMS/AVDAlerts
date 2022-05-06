param metricAlerts_StorageAccountHighThreshold_name string = 'StorageAccountHighThreshold'
param storageAccounts_jh0109_externalid string = '/subscriptions/73f35fe7-5cca-453f-9ac5-e705e1b2f421/resourceGroups/rg-storageacctauth/providers/Microsoft.Storage/storageAccounts/jh0109'
param actionGroups_alertgroup1_externalid string = '/subscriptions/73f35fe7-5cca-453f-9ac5-e705e1b2f421/resourceGroups/rg-storageacctauth/providers/microsoft.insights/actionGroups/alertgroup1'

resource metricAlerts_StorageAccountHighThreshold_name_resource 'microsoft.insights/metricAlerts@2018-03-01' = {
  name: metricAlerts_StorageAccountHighThreshold_name
  location: 'global'
  properties: {
    severity: 2
    enabled: true
    scopes: [
      storageAccounts_jh0109_externalid
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          threshold: 200
          name: 'Metric1'
          metricNamespace: 'microsoft.storage/storageaccounts'
          metricName: 'SuccessServerLatency'
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: false
    targetResourceType: 'Microsoft.Storage/storageAccounts'
    targetResourceRegion: 'eastus'
    actions: [
      {
        actionGroupId: actionGroups_alertgroup1_externalid
        webHookProperties: {}
      }
    ]
  }
}