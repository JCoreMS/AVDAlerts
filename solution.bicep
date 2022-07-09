targetScope = 'subscription'

/*   TO BE ADDED
@description('Determine if you would like to set all deployed alerts to auto-resolve.')
param SetAutoResolve bool = true

@description('Determine if you would like to enable all the alerts after deployment.')
param SetEnabled bool = false
 */

 @description('The Distribution Group that will receive email alerts for AVD.')
param DistributionGroup string = ''

@allowed([
  'd'
  'p'
  't'
])
@description('The environment is which these resources will be deployed, i.e. Development.')
param Environment string = 't'

@description('Azure Region for Resources')
param Location string = deployment().location

@description('The Resource ID for the Log Analytics Workspace.')
param LogAnalyticsWorkspaceResourceId string = ''

@secure()
@description('The SAS token if using a storage account for the repository.')
param ScriptsRepositorySasToken string = ''

@description('The repository URI hosting the scripts for this solution.')
param ScriptsRepositoryUri string = 'https://raw.githubusercontent.com/JCoreMS/AVDAlerts/main/scripts/'

@description('The Resource Group ID for the AVD session host VMs.')
param SessionHostsResourceGroupIds array = [
  ''
]

@description('The Resource IDs for the Azure Files Storage Accounts used for FSLogix profile storage.')
param StorageAccountResourceIds array = [
  ''
]

@description('The Resource IDs for the Azure NetApp Volumes used for FSLogix profile storage.')
param ANFVolumeResourceIds array = [
  ''
]

param Timestamp string = utcNow('yyyyMMddhhmmss')

param Tags object = {}

var AutomationAccountName = 'aa-avdmetrics-${Environment}-${Location}'
var ActionGroupName = 'ag-avdmetrics-${Environment}-${Location}'
//var FunctionAppName = 'fa-avdmetrics-${Environment}-${Location}'
//var HostingPlanName = 'asp-avdmetrics-${Environment}-${Location}'
var LogicAppName = 'la-avdmetrics-${Environment}-${Location}'
var ResourceGroupName = 'rg-avdmetrics-${Environment}-${Location}'
var RoleName = 'Log Analytics Workspace Metrics Contributor'
var RoleDescription = 'This role allows a resource to write to Log Analytics Metrics.'
var RunbookName = 'AvdLogGenerator'
var RunbookScript = 'Get-AzureAvdLogs.ps1'
//var LogAnalyticsWorkspaceName = split(LogAnalyticsWorkspaceResourceId, '/')[8]
var AlertDescriptionHeader = 'Automated AVD Alert Deployment Solution (v0.1)'
var LogAlerts = [
  {
    name: 'AVD-HostPool-No Resources Available'
    displayName: 'AVD-HostPool-No Resources Available'
    description: 'Based on the AVD Healthcheck Agent'
    severity: 1
    evaluationFrequency: 'PT15M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: 'WVDConnections \n| where TimeGenerated > ago (15m) \n| project-away TenantId,SourceSystem  \n| summarize arg_max(TimeGenerated, *), StartTime =  min(iff(State== \'Started\', TimeGenerated , datetime(null) )), ConnectTime = min(iff(State== \'Connected\', TimeGenerated , datetime(null) ))   by CorrelationId  \n| join kind=leftouter (WVDErrors\n    |summarize Errors=makelist(pack(\'Code\', Code, \'CodeSymbolic\', CodeSymbolic, \'Time\', TimeGenerated, \'Message\', Message ,\'ServiceError\', ServiceError, \'Source\', Source)) by CorrelationId  \n    ) on CorrelationId\n| join kind=leftouter (WVDCheckpoints\n    | summarize Checkpoints=makelist(pack(\'Time\', TimeGenerated, \'Name\', Name, \'Parameters\', Parameters, \'Source\', Source)) by CorrelationId  \n    | mv-apply Checkpoints on (  \n        order by todatetime(Checkpoints[\'Time\']) asc\n        | summarize Checkpoints=makelist(Checkpoints)\n        )\n    ) on CorrelationId  \n| project-away CorrelationId1, CorrelationId2  \n| order by TimeGenerated desc\n| where Errors[0].CodeSymbolic == "ConnectionFailedNoHealthyRdshAvailable"\n\n'
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
    name: 'AVD-VM-Local Disk Free Space Warning 90 Percent'
    displayName: 'AVD-VM-Local Disk Free Space Warning 90 Percent'
    description: AlertDescriptionHeader
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
  {
    name: 'AVD-VM-FSLogix Profile Failed'
    displayName: 'AVD-VM-FSLogix Profile Failed (Event Log Indicated Failure)'
    description: AlertDescriptionHeader
    severity: 1
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: 'Event\n| where EventLog == "Microsoft-FSLogix-Apps/Admin"\n| where EventLevelName == "Error"\n\n'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'Computer'
              operator: 'Include'
              values: [
                  '*'
              ]
          }
          {
              name: 'RenderedDescription'
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
  }
  {
    name: 'AVD-VM-Local Disk Free Space Warning 95 Percent'
    displayName: 'AVD-VM-Local Disk Free Space Warning 95 Percent'
    description: AlertDescriptionHeader
    severity: 1
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
          threshold: 5
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
  }
  {
    name: 'AVD-VM-Health Check Failure'
    displayName: 'AVD-VM-Health Check Failure'
    description: '${AlertDescriptionHeader}VM is available for use but one of the dependent resources is in a failed state'
    severity: 1
    evaluationFrequency: 'PT5M'
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
  }
  {  // Based on Runbook script Output to LAW
    name: 'AVD-Storage-Low Space on Azure File Share-15 Percent Remaining'
    displayName: 'AVD-Storage-Low Space on Azure File Share-15 Percent Remaining'
    description: '${AlertDescriptionHeader}This alert is based on the Action Account and Runbook that populates the Log Analytics specificed with the AVD Metrics Deployment Solution.\n-->Last Number in the string is the Percentage Remaining for the Share.\nOutput: ResultsDescription\nStorageType,Subscription,ResourceGroup,StorageAccount,ShareName,Quota,GBUsed,PercentRemaining'
    severity: 2
    evaluationFrequency: 'PT10M'
    windowSize: 'PT10M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: '''
          AzureDiagnostics 
          | where Category has "JobStreams"
          | where StreamType_s has "Output"
          | sort by TimeGenerated
          //  StorageType / Subscription / RG / StorAcct / Share / Quota / GB Used / %Available
          | extend StorageType=split(ResultDescription, ',')[0]
          | extend Subscription=split(ResultDescription, ',')[1]
          | extend ResourceGroup=split(ResultDescription, ',')[2]
          | extend StorageAccount=split(ResultDescription, ',')[3]
          | extend Share=split(ResultDescription, ',')[4]
          | extend GBShareQuota=split(ResultDescription, ',')[5]
          | extend GBUsed=split(ResultDescription, ',')[6]
          | extend PercentAvailable=split(ResultDescription, ',')[7]
          | where PercentAvailable <= 15.00 and PercentAvailable < 5.00          
           '''
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'ResultDescription'
              operator: 'Include'
              values: [
                  '*'
              ]
            }
          ]
          resourceIdColumng: '_ResourceId'
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
  {  // Based on Runbook script Output to LAW
    name: 'AVD-Storage-Low Space on Azure File Share-5 Percent Remaining'
    displayName: 'AVD-Storage-Low Space on Azure File Share-5 Percent Remaining'
    description: '${AlertDescriptionHeader}This alert is based on the Action Account and Runbook that populates the Log Analytics specificed with the AVD Metrics Deployment Solution.\n-->Last Number in the string is the Percentage Remaining for the Share.\nOutput: ResultsDescription\nStorageType,Subscription,ResourceGroup,StorageAccount,ShareName,Quota,GBUsed,PercentRemaining'
    severity: 1
    evaluationFrequency: 'PT10M'
    windowSize: 'PT10M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: '''
          AzureDiagnostics 
          | where Category has "JobStreams"
          | where StreamType_s has "Output"
          | sort by TimeGenerated
          //  StorageType / Subscription / RG / StorAcct / Share / Quota / GB Used / %Available
          | extend StorageType=split(ResultDescription, ',')[0]
          | extend Subscription=split(ResultDescription, ',')[1]
          | extend ResourceGroup=split(ResultDescription, ',')[2]
          | extend StorageAccount=split(ResultDescription, ',')[3]
          | extend Share=split(ResultDescription, ',')[4]
          | extend GBShareQuota=split(ResultDescription, ',')[5]
          | extend GBUsed=split(ResultDescription, ',')[6]
          | extend PercentAvailable=split(ResultDescription, ',')[7]
          | where PercentAvailable <= 5.00          
           '''
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'ResultDescription'
              operator: 'Include'
              values: [
                  '*'
              ]
            }
          ]
          resourceIdColumng: '_ResourceId'
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
]
var MetricAlerts = {
  storageAccounts: [
    {
      name: 'AVD-Storage-Over 200ms Latency for Storage Acct'
      displayName: 'AVD-Storage-Over 200ms Latency for Storage Acct'
      description: AlertDescriptionHeader
      severity: 2
      evaluationFrequency: 'PT5M'
      windowSize: 'PT15M'
      criteria: {
        allOf: [
          {
            threshold: 200
            name: 'Metric1'
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
  ]
  fileShares: [
    {
      name: 'AVD-Storage-Possible Throttling Due to High IOPs'
      displayName: 'AVD-Storage-Possible Throttling Due to High IOPs'
      description: '${AlertDescriptionHeader}\nThis indicates you may be maxing out the allowed IOPs.\nhttps://docs.microsoft.com/en-us/azure/storage/files/storage-troubleshooting-files-performance#how-to-create-an-alert-if-a-file-share-is-throttled'
      severity: 2
      evaluationFrequency: 'PT5M'
      windowSize: 'PT5M'
      criteria: {
        allOf: [
          {
            threshold: 1
            name: 'Metric1'
            metricName: 'Transactions'
            dimensions: [
              {
                name: 'ResponseType'
                operator: 'Include'
                values: [
                  'SuccessWithThrottling'
                  'SuccessWithShareIopsThrottling'
                  'ClientShareIopsThrottlingError'
                ]
              }
              {
                name: 'FileShare'
                operator: 'Include'
                values: [
                  'SuccessWithShareEgressThrottling'
                  'SuccessWithShareIngressThrottling'
                  'SuccessWithShareIopsThrottling'
                  'ClientShareEgressThrottlingError'
                  'ClientShareIngressThrottlingError'
                  'ClientShareIopsThrottlingError'
                ]
              }
            ]
            operator: 'GreaterThanOrEqual'
            timeAggregation: 'Total'
            criterionType: 'StaticThresholdCriterion'
          }
        ]
        'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      }
      targetResourceType: 'Microsoft.Storage/storageAccounts/fileServices'
    }
  ]
  anf: [ 
    {
      name: 'AVD-Storage-Low Space on ANF Share-15 Percent Remaining'
      displayName: 'AVD-Storage-Low Space on ANF Share-15 Percent Remaining'
      description: AlertDescriptionHeader
      severity: 2
      evaluationFrequency: 'PT1H'
      windowSize: 'PT1H'
      criteria: {
        allOf: [
          {
            threshold: 85
            name: 'Metric1'
            metricNamespace: 'microsoft.netapp/netappaccounts/capacitypools/volumes'
            metricName: 'VolumeConsumedSizePercentage'
            operator: 'GreaterThanOrEqual'
            timeAggregation: 'Average'
            criterionType: 'StaticThresholdCriterion'
          }
        ]
        'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      }
      targetResourceType: 'Microsoft.NetApp/netAppAccounts/capacityPools/volumes'
    }
    {
      name: 'AVD-Storage-Low Space on ANF Share-5 Percent Remaining'
      displayName: 'AVD-Storage-Low Space on ANF Share-5 Percent Remaining'
      description: AlertDescriptionHeader
      severity: 1
      evaluationFrequency: 'PT1H'
      windowSize: 'PT1H'
      criteria: {
        allOf: [
          {
            threshold: 95
            name: 'Metric1'
            metricNamespace: 'microsoft.netapp/netappaccounts/capacitypools/volumes'
            metricName: 'VolumeConsumedSizePercentage'
            operator: 'GreaterThanOrEqual'
            timeAggregation: 'Average'
            criterionType: 'StaticThresholdCriterion'
          }
        ]
        'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      }
      targetResourceType: 'Microsoft.NetApp/netAppAccounts/capacityPools/volumes'
    }
  ]
  virtualMachines: [
    {
      name: 'AVD-VM-High CPU 85 Percent'
      displayName: 'AVD-VM-High CPU 85 Percent'
      description: AlertDescriptionHeader
      severity: 2
      evaluationFrequency: 'PT5M'
      windowSize: 'PT5M'
      criteria: {
        allOf: [
          {
            threshold: 85
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
    {
      name: 'AVD-VM-High CPU 95 Percent'
      displayName: 'AVD-VM-High CPU 95 Percent'
      description: AlertDescriptionHeader
      severity: 1
      evaluationFrequency: 'PT5M'
      windowSize: 'PT5M'
      criteria: {
        allOf: [
          {
            threshold: 95
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
    {
      name: 'AVD-VM-Available Memory Less Than 2GB'
      displayName: 'AVD-VM-Available Memory Less Than 2GB'
      description: AlertDescriptionHeader
      severity: 2
      evaluationFrequency: 'PT5M'
      windowSize: 'PT5M'
      criteria: {
        allOf: [
          {
            threshold: 2147483648
            name: 'Metric1'
            metricNamespace: 'microsoft.compute/virtualmachines'
            metricName: 'Available Memory Bytes'
            operator: 'LessThanOrEqual'
            timeAggregation: 'Average'
            criterionType: 'StaticThresholdCriterion'
          }
        ]
        'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      }
      targetResourceType: 'microsoft.compute/virtualmachines'
    }
    {
      name: 'AVD-VM-Available Memory Less Than 1GB'
      displayName: 'AVD-VM-Available Memory Less Than 1GB'
      description: AlertDescriptionHeader
      severity: 1
      evaluationFrequency: 'PT5M'
      windowSize: 'PT5M'
      criteria: {
        allOf: [
          {
            threshold: 1073741824
            name: 'Metric1'
            metricNamespace: 'microsoft.compute/virtualmachines'
            metricName: 'Available Memory Bytes'
            operator: 'LessThanOrEqual'
            timeAggregation: 'Average'
            criterionType: 'StaticThresholdCriterion'
          }
        ]
        'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      }
      targetResourceType: 'microsoft.compute/virtualmachines'
    }
  ]
  // Commenting out below until custom metrics are available in US Gov Cloud
  /* avdCustomMetrics: [
    {
      name: 'AVD-HostPool-UsageAbove80percent'
      severity: 2
      evaluationFrequency: 'PT5M'
      windowSize: 'PT5M'
      criteria: {
        allOf: [
          {
            threshold: 80
            name: 'Metric1'
            metricNamespace: 'avd'
            metricName: 'Session Load (%)'
            operator: 'GreaterThanOrEqual'
            timeAggregation: 'Count'
            criterionType: 'StaticThresholdCriterion'
          }
        ]
        'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      }
      targetResourceType: 'Microsoft.OperationalInsights/workspaces'
    }
  ] */
}



resource resourceGroupAVDMetrics 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: ResourceGroupName
  location: Location
}

module deploymentScript 'modules/deploymentScript.bicep' = {
  name: 'ds_deployment'
  dependsOn: [
    resourceGroupAVDMetrics
  ]
  scope: resourceGroup(ResourceGroupName)
  params: {
    StorageAccountResourceIds: StorageAccountResourceIds
    Location: Location
    Timestamp: Timestamp
  }
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
  scope: resourceGroupAVDMetrics
  params: {
    AutomationAccountName: AutomationAccountName
    DistributionGroup: DistributionGroup
    //FunctionAppName: FunctionAppName
    //HostingPlanName: HostingPlanName
    //HostPoolResourceGroupNames: HostPoolResourceGroupNames
    Location: Location
    LogAnalyticsWorkspaceResourceId: LogAnalyticsWorkspaceResourceId
    //LogAnalyticsWorkspaceName: LogAnalyticsWorkspaceName
    LogAlerts: LogAlerts
    LogicAppName: LogicAppName
    MetricAlerts: MetricAlerts
    RunbookName: RunbookName
    RunbookScript: RunbookScript
    ScriptsRepositorySasToken: ScriptsRepositorySasToken
    ScriptsRepositoryUri: ScriptsRepositoryUri
    SessionHostsResourceGroupIds: SessionHostsResourceGroupIds
    StorageAccountResourceIds: StorageAccountResourceIds
    ActionGroupName: ActionGroupName
    FileServicesResourceIDs: deploymentScript.outputs.fileServicesResourceIDs
    ANFVolumeResourceIds: ANFVolumeResourceIds
    Tags: Tags
  }
}


resource roleAssignment_Subscription 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: guid(subscription().id, AutomationAccountName, 'Reader')
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'c12c1c16-33a1-487b-954d-41c89c60f349') // Reader and Data Access
    principalId: resources.outputs.automationAccountPrincipalId
    principalType: 'ServicePrincipal'
  }
}



// Commenting out Function App resources until Custom Metrics / Logs is supported in Azure US Government
/* resource roleCustomAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
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

resource roleLAWContributorAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(subscription().subscriptionId, FunctionAppName, 'Log Analytics Contributor')
  properties: {
    principalId: resources.outputs.functionAppPrincipalID
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '92aaf0da-9dab-42b6-94a3-d43ce8d16293') // Log Analytics Contributor
  }
} */
