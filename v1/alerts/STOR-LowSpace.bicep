param metricAlerts_AVD_Storage_LowSpace_name string = 'StorageLowSpace'
param storageAccounts_avdlabprof_externalid string = '/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-AVDLab-Resources/providers/Microsoft.Storage/storageAccounts/avdlabprof'
param actiongroups_actgrp_eastus2_avd_externalid string = '/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-avdlab-manage/providers/microsoft.insights/actiongroups/actgrp-eastus2-avd'

resource metricAlerts_AVD_Storage_LowSpace_name_resource 'microsoft.insights/metricAlerts@2018-03-01' = {
  name: metricAlerts_AVD_Storage_LowSpace_name
  location: 'global'
  properties: {
    severity: 2
    enabled: true
    scopes: [
      '${storageAccounts_avdlabprof_externalid}/fileServices/default'
    ]
    evaluationFrequency: 'PT30M'
    windowSize: 'PT6H'
    criteria: {
      allOf: [
        {
          threshold: 96636764160
          name: 'Metric1'
          metricNamespace: 'microsoft.storage/storageaccounts/fileservices'
          metricName: 'FileCapacity'
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    autoMitigate: true
    targetResourceType: 'Microsoft.Storage/storageAccounts/fileServices'
    targetResourceRegion: 'eastus'
    actions: [
      {
        actionGroupId: actiongroups_actgrp_eastus2_avd_externalid
        webHookProperties: {}
      }
    ]
  }
}
