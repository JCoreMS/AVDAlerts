param scheduledqueryrules_ar_test_name string = 'ar-test'
param actionGroups_actgrp_eastus2_AVD_externalid string = '/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-AVDLab-Manage/providers/microsoft.insights/actionGroups/actgrp-eastus2-AVD'

resource scheduledqueryrules_ar_test_name_resource 'microsoft.insights/scheduledqueryrules@2021-08-01' = {
  name: scheduledqueryrules_ar_test_name
  location: 'eastus2'
  properties: {
    displayName: scheduledqueryrules_ar_test_name
    severity: 2
    enabled: true
    evaluationFrequency: 'PT1H'
    scopes: [
      '/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9'
    ]
    targetResourceTypes: []
    windowSize: 'PT1H'
    criteria: {
      allOf: [
        {
          query: 'WVDConnections \n| where TimeGenerated > ago (1h) \n| project-away TenantId,SourceSystem  \n| summarize arg_max(TimeGenerated, *), StartTime =  min(iff(State== \'Started\', TimeGenerated , datetime(null) )), ConnectTime = min(iff(State== \'Connected\', TimeGenerated , datetime(null) ))   by CorrelationId  \n| join kind=leftouter (WVDErrors\n    |summarize Errors=makelist(pack(\'Code\', Code, \'CodeSymbolic\', CodeSymbolic, \'Time\', TimeGenerated, \'Message\', Message ,\'ServiceError\', ServiceError, \'Source\', Source)) by CorrelationId  \n    ) on CorrelationId\n| join kind=leftouter (WVDCheckpoints\n    | summarize Checkpoints=makelist(pack(\'Time\', TimeGenerated, \'Name\', Name, \'Parameters\', Parameters, \'Source\', Source)) by CorrelationId  \n    | mv-apply Checkpoints on (  \n        order by todatetime(Checkpoints[\'Time\']) asc\n        | summarize Checkpoints=makelist(Checkpoints)\n        )\n    ) on CorrelationId  \n| project-away CorrelationId1, CorrelationId2  \n| order by TimeGenerated desc\n| where Errors[0].CodeSymbolic == "ConnectionFailedNoHealthyRdshAvailable"\n\n'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'UserName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'SessionHostName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          resourceIdColumn: '_ResourceId'
          operator: 'GreaterThanOrEqual'
          threshold: 1
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