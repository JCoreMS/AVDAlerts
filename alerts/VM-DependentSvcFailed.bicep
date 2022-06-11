param Name string = 'AVD-VM-HealthCheck Item Failure'
param Location string
param LogAnalyticsWorkspaceResourceId string = '/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-AVDLab-Manage/providers/Microsoft.OperationalInsights/workspaces/law-eastus2-AVDVMs'
param ActionGroupResourceId string = '/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-avdlab-manage/providers/microsoft.insights/actiongroups/actgrp-eastus2-avd'

resource scheduledqueryrule 'microsoft.insights/scheduledqueryrules@2021-08-01' = {
  name: Name
  location: Location
  properties: {
    displayName: Name
    description: 'VM is available for use but one of the dependent resources is in a failed state'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT5M'
    scopes: [
      LogAnalyticsWorkspaceResourceId
    ]
    targetResourceTypes: [
      'Microsoft.OperationalInsights/workspaces'
    ]
    windowSize: 'PT5M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: '// HealthChecks of SessionHost \n// Renders a summary of SessionHost health status. \nlet MapToDesc = (idx:long) {\n    case(idx == 0,  "DomainJoin",\n         idx == 1,  "DomainTrust",\n         idx == 2,  "FSLogix",\n         idx == 3,  "SxSStack",\n         idx == 4,  "URLCheck",\n         idx == 5,  "GenevaAgent",\n         idx == 6,  "DomainReachable",\n         idx == 7,  "WebRTCRedirector",\n         idx == 8,  "SxSStackEncryption",\n         idx == 9,  "IMDSReachable",\n         idx == 10, "MSIXPackageStaging",\n         "InvalidIndex")\n};\nWVDAgentHealthStatus\n| where TimeGenerated > ago(10m)\n| where Status != \'Available\'\n| where AllowNewSessions = True\n| extend CheckFailed = parse_json(SessionHostHealthCheckResult)\n| mv-expand CheckFailed\n| where CheckFailed.AdditionalFailureDetails.ErrorCode != 0\n| extend HealthCheckName = tolong(CheckFailed.HealthCheckName)\n| extend HealthCheckResult = tolong(CheckFailed.HealthCheckResult)\n| extend HealthCheckDesc = MapToDesc(HealthCheckName)\n\n'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'SessionHostName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
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
        ActionGroupResourceId
      ]
    }
  }
}
