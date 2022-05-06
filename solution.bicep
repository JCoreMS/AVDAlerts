targetScope = 'subscription'

@description('The Distribution Group that will receive email alerts for AVD.')
param DistributionGroup string

@description('Resource Group with Host Pool "type" Resources (may be different than RG with VMs)')
param HostPoolResourceGroupNames array

@description('Azure Region for Resources')
param Location string = deployment().location

@description('The Resource ID for the Log Analytics Workspace.')
param LogAnalyticsWorkspaceResourceId string

@description('The Name for Log Analytics Workspace to store Metrics data')
param LogAnalyticsWorkSpaceName string

@description('The Name of the Resource Group to create resources in.')
param ResourceGroupName string

@description('The Resource Group ID for the AVD session hosts.')
param SessionHostResourceGroupId string

@description('The Resource IDs for the Storage Accounts used for FSLogix profile storage.')
param StorageAccountResourceIds array

param Tags object = {}


var DataActions = [
  'Microsoft.Insights/Telemetry/Write'
]
var FunctionAppName = 'fa-AVDMetrics-${Location}-autodeploy'
var HostingPlanName = 'asp-${Location}-AVDMetricsFuncApp'
var RoleName = 'AVDFunctionApp - Write to Metrics'
var RoleDescription = 'This role allows the AVD Function App to write to a Log Analytics Metrics for additional AVD monitoring and alerting.'
var RoleDefinitionName = guid(subscription().id, string(DataActions))
var LogAlerts = [
  {
    name: 'AvdNoResourcesAvailable'
    displayName: 'AVD - No Resources Available'
    severity: 2
    evaluationFrequency: 'PT1H'
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
  }
  {
    name: 'LocalDiskFreeSpaceWarning90PercentFull'
    displayName: 'Local Disk Free Space Warning - 90 Percent Full'
    severity: 2
    evaluationFrequency: 'PT15M'
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
  }
]
var MetricAlerts = {
  storageAccounts: [
    {
      name: 'StorageAccountHighThreshold'
      severity: 2
      scopes: [
  
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
      targetResourceType: 'Microsoft.Storage/storageAccounts'
    }
  /*   {
      name: 'Storage Low Space'
      severity: 2
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
      targetResourceType: 'Microsoft.Storage/storageAccounts/fileServices'
    } */
  ]
  virtualMachines: [
    {
      name: 'CPU Percentage'
      severity: 2
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
      targetResourceType: 'microsoft.compute/virtualmachines'
    }
  ]
}


resource resourceGroupAlerts 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: ResourceGroupName
  location: Location
}

resource roleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' = {
  name: RoleDefinitionName
    properties: {
    roleName: RoleName
    description: RoleDescription
    type: 'customRole'
    permissions: [
      {
        dataActions: DataActions
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

module resources 'modules/resources.bicep' = {
  scope: resourceGroupAlerts
  name: 'MonitoringResourcesDeployment'
  params: {
    DistributionGroup: DistributionGroup
    FunctionAppName: FunctionAppName
    HostingPlanName: HostingPlanName
    HostPoolResourceGroupNames: HostPoolResourceGroupNames
    Location: Location
    LogAlerts: LogAlerts
    LogAnalyticsWorkspaceResourceId: LogAnalyticsWorkspaceResourceId
    LogAnalyticsWorkspaceName: LogAnalyticsWorkSpaceName
    MetricAlerts: MetricAlerts
    SessionHostResourceGroupId: SessionHostResourceGroupId
    StorageAccountResourceIds: StorageAccountResourceIds
    Tags: Tags
  }
}

resource roleCustomAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(subscription().subscriptionId, FunctionAppName, roleDefinition.name)
  properties: {
    principalId: resources.outputs.functionAppPrincipalID
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleDefinition.id
  }
}

resource roleReaderAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(subscription().subscriptionId, FunctionAppName, 'Reader')
  properties: {
    principalId: resources.outputs.functionAppPrincipalID
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7') // Reader
  }
}