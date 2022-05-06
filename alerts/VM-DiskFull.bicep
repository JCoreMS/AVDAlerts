param scheduledqueryrules_Local_Disk_Free_Space_Warning_90_percent_full_name string = 'Local Disk Free Space Warning - 90 percent full'
param workspaces_law_eastus2_AVDVMs_externalid string = '/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-AVDLab-Manage/providers/Microsoft.OperationalInsights/workspaces/law-eastus2-AVDVMs'
param actionGroups_actgrp_eastus2_AVD_externalid string = '/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-AVDLab-Manage/providers/microsoft.insights/actionGroups/actgrp-eastus2-AVD'

resource scheduledqueryrules_Local_Disk_Free_Space_Warning_90_percent_full_name_resource 'microsoft.insights/scheduledqueryrules@2021-08-01' = {
  name: scheduledqueryrules_Local_Disk_Free_Space_Warning_90_percent_full_name
  location: 'eastus2'
  properties: {
    displayName: scheduledqueryrules_Local_Disk_Free_Space_Warning_90_percent_full_name
    severity: 2
    enabled: true
    evaluationFrequency: 'PT15M'
    scopes: [
      workspaces_law_eastus2_AVDVMs_externalid
    ]
    targetResourceTypes: [
      'Microsoft.OperationalInsights/workspaces'
    ]
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: 'InsightsMetrics\n| where Origin == "vm.azm.ms"\n| where Namespace == "LogicalDisk" and Name == "FreeSpacePercentage"\n| summarize AggregatedValue = avg(Val) by bin(TimeGenerated, 15m), Computer, _ResourceId\n'
          timeAggregation: 'Average'
          metricMeasureColumn: 'AggregatedValue'
          dimensions: []
          resourceIdColumn: '_ResourceId'
          operator: 'LessThan'
          threshold: 10
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: false
    actions: {
      actionGroups: [
        actionGroups_actgrp_eastus2_AVD_externalid
      ]
    }
  }
}