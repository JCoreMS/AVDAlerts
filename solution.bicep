targetScope = 'subscription'

@description('The Distribution Group that will receive email alerts for AVD.')
param DistributionGroup string = 'jamasten@microsoft.com'

@allowed([
  'd'
  'p'
  't'
])
@description('The environment is which these resources will be deployed, i.e. Development.')
param Environment string = 'd'

@description('Resource Group with Host Pool "type" Resources (may be different than RG with VMs)')
param HostPoolResourceGroupNames array = [
  'hp-fs-peo-va-d-00'
]

@description('Azure Region for Resources')
param Location string = deployment().location

@description('The Resource ID for the Log Analytics Workspace.')
param LogAnalyticsWorkspaceResourceId string = '/subscriptions/a7576b41-cb1a-4f34-9f18-0e0b0287a1a0/resourcegroups/rg-shd-svc-d-va/providers/microsoft.operationalinsights/workspaces/law-shd-net-d-va'

@description('The Resource Group ID for the AVD session hosts.')
param SessionHostResourceGroupId string = '/subscriptions/a7576b41-cb1a-4f34-9f18-0e0b0287a1a0/resourceGroups/rg-fs-peo-va-d-hosts-00'

@description('The Resource IDs for the Storage Accounts used for FSLogix profile storage.')
param StorageAccountResourceIds array = [
  '/subscriptions/a7576b41-cb1a-4f34-9f18-0e0b0287a1a0/resourceGroups/rg-fs-peo-va-d-storage-00/providers/Microsoft.Storage/storageAccounts/stfspeovad0000'
]

param Tags object = {}


var ActionGroupName = 'ag-avdmetrics-${Environment}-${Location}'
var FunctionAppName = 'fa-avdmetrics-${Environment}-${Location}'
var HostingPlanName = 'asp-avdmetrics-${Environment}-${Location}'
var ResourceGroupName = 'rg-avdmetrics-${Environment}-${Location}'
var RoleName = 'Log Analytics Workspace Metrics Contributor'
var RoleDescription = 'This role allows a resource to write to Log Analytics Metrics.'
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


resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: ResourceGroupName
  location: Location
}

resource roleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' = {
  name: guid(RoleName)
    properties: {
    roleName: RoleName
    description: RoleDescription
    type: 'customRole'
    permissions: [
      {
        dataActions: [
          'Microsoft.Insights/Telemetry/Write'
        ]
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

module resources 'modules/resources.bicep' = {
  name: 'MonitoringResourcesDeployment'
  scope: resourceGroup
  params: {
    DistributionGroup: DistributionGroup
    FunctionAppName: FunctionAppName
    HostingPlanName: HostingPlanName
    HostPoolResourceGroupNames: HostPoolResourceGroupNames
    Location: Location
    LogAlerts: LogAlerts
    LogAnalyticsWorkspaceResourceId: LogAnalyticsWorkspaceResourceId
    MetricAlerts: MetricAlerts
    SessionHostResourceGroupId: SessionHostResourceGroupId
    StorageAccountResourceIds: StorageAccountResourceIds
    ActionGroupName: ActionGroupName
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
