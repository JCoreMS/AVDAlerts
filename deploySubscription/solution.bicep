targetScope = 'subscription'

/*   TO BE ADDED
@description('Determine if you would like to set all deployed alerts to auto-resolve.')
param SetAutoResolve bool = true

@description('Determine if you would like to enable all the alerts after deployment.')
param SetEnabled bool = false
 */

@description('Alert Name Prefix')
param AlertNamePrefix string = 'AVD-'

@description('The Distribution Group that will receive email alerts for AVD.')
param DistributionGroup string = ''

@allowed([
  'd'
  'p'
  't'
])
@description('The environment is which these resources will be deployed, i.e. Test, Production, Development.')
param Environment string = 't'

@description('Azure Region for Resources.')
param Location string

@description('The Resource ID for the Log Analytics Workspace.')
param LogAnalyticsWorkspaceResourceId string

@description('The Resource Group ID for the AVD session host VMs.')
param SessionHostsResourceGroupIds array = []

@description('The Resource IDs for the Azure Files Storage Accounts used for FSLogix profile storage.')
param StorageAccountResourceIds array = []

@description('The Resource IDs for the Azure NetApp Volumes used for FSLogix profile storage.')
param ANFVolumeResourceIds array = []

@description('Resource Group Name to deploy AVD Alert resources to. (new or existing) If not set default will be rg-avdmetrics-<environment>-<region>')
param UserResourceGroup string
//param Timestamp string = utcNow('yyyyMMddhhmmss')

param Tags object = {}

var AutomationAccountName = 'aa-avdmetrics-${Environment}-${Location}'
var ActionGroupName = 'ag-avdmetrics-${Environment}-${Location}'
//var FunctionAppName = 'fa-avdmetrics-${Environment}-${Location}'
//var HostingPlanName = 'asp-avdmetrics-${Environment}-${Location}'
var LogicAppName = 'la-avdmetrics-${Environment}-${Location}'
var ResourceGroupName = 'rg-avdmetrics-${Environment}-${Location}'
var RunbookNameGetStorage = 'AvdStorageLogData'
var RunbookNameGetHostPool = 'AvdHostPoolLogData'
var RunbookScriptGetStorage = 'Get-StorAcctInfov2.ps1'
var RunbookScriptGetHostPool = 'Get-HostPoolInfo.ps1'
var ScriptsRepositoryUri = 'https://raw.githubusercontent.com/JCoreMS/AVDAlerts/main/deploySubscription/scripts/'
var AlertDescriptionHeader = 'Automated AVD Alert Deployment Solution (v0.9)\n'
var RoleAssignments = {
  DesktopVirtualizationRead: {
    Name: 'Desktop-Virtualization-Reader'
    GUID: '49a72310-ab8d-41df-bbb0-79b649203868'
  }
  StoreAcctContrib: {
    Name: 'Storage-Account-Contributor'
    GUID: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
  }
  LogAnalyticsContributor: {
    Name: 'LogAnalytics-Contributor'
    GUID: '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
  }
}
// 'c12c1c16-33a1-487b-954d-41c89c60f349'  // Reader and Data Access (Storage Account Keys)
// 'acdd72a7-3385-48ef-bd42-f606fba81ae7'  // Reader
// '49a72310-ab8d-41df-bbb0-79b649203868'  // Desktop Virtualization Reader (May be able to replace Reader with this)
// '17d1049b-9a84-46fb-8f53-869881c3d3ab'  // Storage Account Contributor
// '92aaf0da-9dab-42b6-94a3-d43ce8d16293'  // Log Analtyics Contributor - allows writing to workspace for Host Pool and Storage Logic Apps

var LogAlerts = [
  {
    name: '${AlertNamePrefix}HostPool-No Resources Available'
    displayName: '${AlertNamePrefix}HostPool-No Resources Available'
    description: AlertDescriptionHeader
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
    name: '${AlertNamePrefix}HostPool-Disconnected User over 24 Hours'
    displayName: '${AlertNamePrefix}HostPool-Disconnected User over 24 Hours'
    description: AlertDescriptionHeader
    severity: 2
    evaluationFrequency: 'PT1H'
    windowSize: 'PT1H'
    criteria: {
      allOf: [
        {
          query: '// Session duration \n// Lists users by session duration in the last 24 hours. \n// The "State" provides information on the connection stage of an activity.\n// The delta between "Connected" and "Completed" provides the connection time for a specific connection.\nWVDConnections \n| where TimeGenerated > ago(24h) \n| where State == "Connected"  \n| project CorrelationId , UserName, ConnectionType, StartTime=TimeGenerated, SessionHostName\n| join (WVDConnections  \n    | where State == "Completed"  \n    | project EndTime=TimeGenerated, CorrelationId)  \n    on CorrelationId  \n| project Duration = EndTime - StartTime, ConnectionType, UserName, SessionHostName\n| where Duration >= timespan(24:00:00)\n| sort by Duration desc'
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
    name: '${AlertNamePrefix}HostPool-Disconnected User over 72 Hours'
    displayName: '${AlertNamePrefix}HostPool-Disconnected User over 72 Hours'
    description: AlertDescriptionHeader
    severity: 1
    evaluationFrequency: 'PT1H'
    windowSize: 'PT1H'
    criteria: {
      allOf: [
        {
          query: '// Session duration \n// Lists users by session duration in the last 24 hours. \n// The "State" provides information on the connection stage of an activity.\n// The delta between "Connected" and "Completed" provides the connection time for a specific connection.\nWVDConnections \n| where TimeGenerated > ago(24h) \n| where State == "Connected"  \n| project CorrelationId , UserName, ConnectionType, StartTime=TimeGenerated, SessionHostName\n| join (WVDConnections  \n    | where State == "Completed"  \n    | project EndTime=TimeGenerated, CorrelationId)  \n    on CorrelationId  \n| project Duration = EndTime - StartTime, ConnectionType, UserName, SessionHostName\n| where Duration >= timespan(72:00:00)\n| sort by Duration desc'
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
    name: '${AlertNamePrefix}VM-Local Disk Free Space 10 Percent'
    displayName: '${AlertNamePrefix}VM-Local Disk Free Space 10%'
    description: AlertDescriptionHeader
    severity: 2
    evaluationFrequency: 'PT15M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: 'Perf\n| where TimeGenerated > ago(15m)\n| where ObjectName == "LogicalDisk" and CounterName == "% Free Space"\n| where InstanceName !contains "D:"\n| where InstanceName  !contains "_Total"| where CounterValue <= 10.00'
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
              name: 'CounterValue'
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
    name: '${AlertNamePrefix}VM-Local Disk Free Space 5 Percent'
    displayName: '${AlertNamePrefix}VM-Local Disk Free Space 5%'
    description: AlertDescriptionHeader
    severity: 1
    evaluationFrequency: 'PT15M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: 'Perf\n| where TimeGenerated > ago(15m)\n| where ObjectName == "LogicalDisk" and CounterName == "% Free Space"\n| where InstanceName !contains "D:"\n| where InstanceName  !contains "_Total"| where CounterValue <= 5.00'
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
              name: 'CounterValue'
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
    name: '${AlertNamePrefix}VM-FSLogix Profile-LessThan5PercentFree'
    displayName: '${AlertNamePrefix}VM-FSLogix Profile Failed (Less Than 5% Free Space)'
    description: AlertDescriptionHeader
    severity: 2
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: 'Event\n| where EventLog == "Microsoft-FSLogix-Apps/Admin"\n| where EventLevelName == "Error"\n| where EventID == 33\n'
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
    name: '${AlertNamePrefix}VM-FSLogix Profile-LessThan2PercentFree'
    displayName: '${AlertNamePrefix}VM-FSLogix Profile Failed (Less Than 2% Free Space)'
    description: AlertDescriptionHeader
    severity: 1
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: 'Event\n| where EventLog == "Microsoft-FSLogix-Apps/Admin"\n| where EventLevelName == "Error"\n| where EventID == 34\n'
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
    name: '${AlertNamePrefix}VM-FSLogix Profile-NetworkIssue'
    displayName: '${AlertNamePrefix}VM-FSLogix Profile Failed due to Network Issue'
    description: AlertDescriptionHeader
    severity: 1
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: 'Event\n| where EventLog == "Microsoft-FSLogix-Apps/Admin"\n| where EventLevelName == "Error"\n| where EventID == 43\n'
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
    name: '${AlertNamePrefix}VM-FSLogix Profile-FailedAttachVHD'
    displayName: '${AlertNamePrefix}VM-FSLogix Profile Disk Failed to Attach'
    description: AlertDescriptionHeader
    severity: 1
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: 'Event\n| where EventLog == "Microsoft-FSLogix-Apps/Admin"\n| where EventLevelName == "Error"\n| where EventID == 52 or EventID == 40\n'
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
    name: '${AlertNamePrefix}VM-FSLogix Profile-SerivceDisabled'
    displayName: '${AlertNamePrefix}VM-FSLogix Profile Service Disabled'
    description: AlertDescriptionHeader
    severity: 1
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: 'Event\n| where EventLog == "Microsoft-FSLogix-Apps/Admin"\n| where EventLevelName == "Error"\n| where EventID == 60\n'
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
    name: '${AlertNamePrefix}VM-FSLogix Profile-DiskCompactFailed'
    displayName: '${AlertNamePrefix}VM-FSLogix Profile Disk Compaction Failed'
    description: AlertDescriptionHeader
    severity: 2
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: 'Event\n| where EventLog == "Microsoft-FSLogix-Apps/Admin"\n| where EventLevelName == "Error"\n| where EventID == 62 or EventID == 63\n'
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
    name: '${AlertNamePrefix}VM-Health Check Failure'
    displayName: '${AlertNamePrefix}VM-Health Check Failure'
    description: '${AlertDescriptionHeader}VM is available for use but one of the dependent resources is in a failed state'
    severity: 1
    evaluationFrequency: 'PT15M'
    windowSize: 'PT15M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: '// HealthChecks of SessionHost \n// Renders a summary of SessionHost health status. \nlet MapToDesc = (idx:long) {\n    case(idx == 0,  "DomainJoin",\n         idx == 1,  "DomainTrust",\n         idx == 2,  "FSLogix",\n         idx == 3,  "SxSStack",\n         idx == 4,  "URLCheck",\n         idx == 5,  "GenevaAgent",\n         idx == 6,  "DomainReachable",\n         idx == 7,  "WebRTCRedirector",\n         idx == 8,  "SxSStackEncryption",\n         idx == 9,  "IMDSReachable",\n         idx == 10, "MSIXPackageStaging",\n         "InvalidIndex")\n};\nWVDAgentHealthStatus\n| where TimeGenerated > ago(10m)\n| where Status != \'Available\'\n| where AllowNewSessions = True\n| extend CheckFailed = parse_json(SessionHostHealthCheckResult)\n| mv-expand CheckFailed\n| where CheckFailed.AdditionalFailureDetails.ErrorCode != 0\n| extend HealthCheckName = tolong(CheckFailed.HealthCheckName)\n| extend HealthCheckResult = tolong(CheckFailed.HealthCheckResult)\n| extend HealthCheckDesc = MapToDesc(HealthCheckName)\n| where HealthCheckDesc != \'InvalidIndex\'\n'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'SessionHostName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'HealthCheckDesc'
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
  { // Based on Runbook script Output to LAW
    name: '${AlertNamePrefix}Storage-Low Space on Azure File Share-15 Percent Remaining'
    displayName: '${AlertNamePrefix}Storage-Low Space on Azure File Share-15% Remaining'
    description: '${AlertDescriptionHeader}This alert is based on the Action Account and Runbook that populates the Log Analytics specificed with the AVD Metrics Deployment Solution.\nNOTE: The Runbook will FAIL if Networking for the storage account has anything other than "Enabled from all networks"\n-->Last Number in the string is the Percentage Remaining for the Share.\nOutput: ResultsDescription\nStorageType,Subscription,ResourceGroup,StorageAccount,ShareName,Quota,GBUsed,PercentRemaining'
    severity: 2
    evaluationFrequency: 'PT10M'
    windowSize: 'PT1H'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: '''
          AzureDiagnostics 
          | where Category has "JobStreams" and StreamType_s == "Output" and RunbookName_s == "AvdStorageLogData"
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
  { // Based on Runbook script Output to LAW
    name: '${AlertNamePrefix}Storage-Low Space on Azure File Share-5 Percent Remaining'
    displayName: '${AlertNamePrefix}Storage-Low Space on Azure File Share-5% Remaining'
    description: '${AlertDescriptionHeader}This alert is based on the Action Account and Runbook that populates the Log Analytics specificed with the AVD Metrics Deployment Solution.\nNOTE: The Runbook will FAIL if Networking for the storage account has anything other than "Enabled from all networks"\n-->Last Number in the string is the Percentage Remaining for the Share.\nOutput: ResultsDescription\nStorageType,Subscription,ResourceGroup,StorageAccount,ShareName,Quota,GBUsed,PercentRemaining'
    severity: 1
    evaluationFrequency: 'PT10M'
    windowSize: 'PT1H'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: '''
          AzureDiagnostics 
          | where Category has "JobStreams" and StreamType_s == "Output" and RunbookName_s == "AvdStorageLogData"
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
  { // Based on Runbook script Output to LAW
    name: '${AlertNamePrefix}HostPool-Capacity-85Percent'
    displayName: '${AlertNamePrefix}HostPool-Capacity 85%'
    description: '${AlertDescriptionHeader}This alert is based on the Action Account and Runbook that populates the Log Analytics specificed with the AVD Metrics Deployment Solution.\n-->Last Number in the string is the Percentage Remaining for the Host Pool\nOutput is:\nHostPoolName|ResourceGroup|Type|MaxSessionLimit|NumberHosts|TotalUsers|DisconnectedUser|ActiveUsers|SessionsAvailable|HostPoolPercentageLoad'
    severity: 2
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: '''
          AzureDiagnostics 
          | where Category has "JobStreams" and StreamType_s == "Output" and RunbookName_s == "AvdHostPoolLogData"
          | sort by TimeGenerated
          | where TimeGenerated > now() - 5m
          | extend HostPoolName=tostring(split(ResultDescription, '|')[0])
          | extend ResourceGroup=tostring(split(ResultDescription, '|')[1])
          | extend Type=tostring(split(ResultDescription, '|')[2])
          | extend MaxSessionLimit=toint(split(ResultDescription, '|')[3])
          | extend NumberSessionHosts=toint(split(ResultDescription, '|')[4])
          | extend UserSessionsTotal=toint(split(ResultDescription, '|')[5])
          | extend UserSessionsDisconnected=toint(split(ResultDescription, '|')[6])
          | extend UserSessionsActive=toint(split(ResultDescription, '|')[7])
          | extend UserSessionsAvailable=toint(split(ResultDescription, '|')[8])
          | extend HostPoolPercentLoad=toint(split(ResultDescription, '|')[9])
          | where HostPoolPercentLoad >= 85 and HostPoolPercentLoad < 95        
           '''
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'HostPoolName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'UserSessionsTotal'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'UserSessionsDisconnected'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'UserSessionsActive'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'UserSessionsAvailable'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'HostPoolPercentLoad'
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
  { // Based on Runbook script Output to LAW
    name: '${AlertNamePrefix}HostPool-Capacity-50Percent'
    displayName: '${AlertNamePrefix}HostPool-Capacity 50%'
    description: '${AlertDescriptionHeader}This alert is based on the Action Account and Runbook that populates the Log Analytics specificed with the AVD Metrics Deployment Solution.\n-->Last Number in the string is the Percentage Remaining for the Host Pool\nOutput is:\nHostPoolName|ResourceGroup|Type|MaxSessionLimit|NumberHosts|TotalUsers|DisconnectedUser|ActiveUsers|SessionsAvailable|HostPoolPercentageLoad'
    severity: 3
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: '''
          AzureDiagnostics 
          | where Category has "JobStreams" and StreamType_s == "Output" and RunbookName_s == "AvdHostPoolLogData"
          | sort by TimeGenerated
          | where TimeGenerated > now() - 5m
          | extend HostPoolName=tostring(split(ResultDescription, '|')[0])
          | extend ResourceGroup=tostring(split(ResultDescription, '|')[1])
          | extend Type=tostring(split(ResultDescription, '|')[2])
          | extend MaxSessionLimit=toint(split(ResultDescription, '|')[3])
          | extend NumberSessionHosts=toint(split(ResultDescription, '|')[4])
          | extend UserSessionsTotal=toint(split(ResultDescription, '|')[5])
          | extend UserSessionsDisconnected=toint(split(ResultDescription, '|')[6])
          | extend UserSessionsActive=toint(split(ResultDescription, '|')[7])
          | extend UserSessionsAvailable=toint(split(ResultDescription, '|')[8])
          | extend HostPoolPercentLoad=toint(split(ResultDescription, '|')[9])
          | where HostPoolPercentLoad >= 50 and HostPoolPercentLoad < 85         
           '''
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'HostPoolName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'UserSessionsTotal'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'UserSessionsDisconnected'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'UserSessionsActive'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'UserSessionsAvailable'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'HostPoolPercentLoad'
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
  { // Based on Runbook script Output to LAW
    name: '${AlertNamePrefix}HostPool-Capacity-95Percent'
    displayName: '${AlertNamePrefix}HostPool-Capacity 95%'
    description: '${AlertDescriptionHeader}This alert is based on the Action Account and Runbook that populates the Log Analytics specificed with the AVD Metrics Deployment Solution.\n-->Last Number in the string is the Percentage Remaining for the Host Pool\nOutput is:\nHostPoolName|ResourceGroup|Type|MaxSessionLimit|NumberHosts|TotalUsers|DisconnectedUser|ActiveUsers|SessionsAvailable|HostPoolPercentageLoad'
    severity: 1
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: '''
          AzureDiagnostics 
          | where Category has "JobStreams" and StreamType_s == "Output" and RunbookName_s == "AvdHostPoolLogData"
          | sort by TimeGenerated
          | where TimeGenerated > now() - 5m
          | extend HostPoolName=tostring(split(ResultDescription, '|')[0])
          | extend ResourceGroup=tostring(split(ResultDescription, '|')[1])
          | extend Type=tostring(split(ResultDescription, '|')[2])
          | extend MaxSessionLimit=toint(split(ResultDescription, '|')[3])
          | extend NumberSessionHosts=toint(split(ResultDescription, '|')[4])
          | extend UserSessionsTotal=toint(split(ResultDescription, '|')[5])
          | extend UserSessionsDisconnected=toint(split(ResultDescription, '|')[6])
          | extend UserSessionsActive=toint(split(ResultDescription, '|')[7])
          | extend UserSessionsAvailable=toint(split(ResultDescription, '|')[8])
          | extend HostPoolPercentLoad=toint(split(ResultDescription, '|')[9])
          | where HostPoolPercentLoad >= 95         
           '''
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'HostPoolName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'UserSessionsTotal'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'UserSessionsDisconnected'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'UserSessionsActive'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'UserSessionsAvailable'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'HostPoolPercentLoad'
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
      name: '${AlertNamePrefix}Storage-Over 50ms Latency for Storage Acct'
      displayName: '${AlertNamePrefix}Storage-Over 50ms Latency for Storage Acct'
      description: '${AlertDescriptionHeader}\nThis could indicate a lag or poor performance for user Profiles or Apps using MSIX App Attach.\nThis alert is specific to the Storage Account itself and does not include network latency.\nFor additional details on troubleshooting see:\n"https://learn.microsoft.com/en-us/azure/storage/files/storage-troubleshooting-files-performance#very-high-latency-for-requests"'
      severity: 2
      evaluationFrequency: 'PT15M'
      windowSize: 'PT15M'
      criteria: {
        allOf: [
          {
            threshold: 50
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
    {
      name: '${AlertNamePrefix}Storage-Over 100ms Latency for Storage Acct'
      displayName: '${AlertNamePrefix}Storage-Over 100ms Latency for Storage Acct'
      description: '${AlertDescriptionHeader}\nThis could indicate a lag or poor performance for user Profiles or Apps using MSIX App Attach.\nThis alert is specific to the Storage Account itself and does not include network latency.\nFor additional details on troubleshooting see:\n"https://learn.microsoft.com/en-us/azure/storage/files/storage-troubleshooting-files-performance#very-high-latency-for-requests"'
      severity: 1
      evaluationFrequency: 'PT15M'
      windowSize: 'PT15M'
      criteria: {
        allOf: [
          {
            threshold: 100
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
    {
      name: '${AlertNamePrefix}Storage-Over 50ms Latency Between Client-Storage'
      displayName: '${AlertNamePrefix}Storage-Over 50ms Latency Between Client-Storage'
      description: '${AlertDescriptionHeader}\nThis could indicate a lag or poor performance for user Profiles or Apps using MSIX App Attach.\nThis is a total latency from end to end between the Host VM and Storage to include network.\nFor additional details on troubleshooting see:\n"https://learn.microsoft.com/en-us/azure/storage/files/storage-troubleshooting-files-performance#very-high-latency-for-requests"'
      severity: 2
      evaluationFrequency: 'PT15M'
      windowSize: 'PT15M'
      criteria: {
        allOf: [
          {
            threshold: 50
            name: 'Metric1'
            metricName: 'SuccessE2ELatency'
            operator: 'GreaterThan'
            timeAggregation: 'Average'
            criterionType: 'StaticThresholdCriterion'
          }
        ]
        'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      }
      targetResourceType: 'Microsoft.Storage/storageAccounts'
    }
    {
      name: '${AlertNamePrefix}Storage-Over 100ms Latency Between Client-Storage'
      displayName: '${AlertNamePrefix}Storage-Over 100ms Latency Between Client-Storage'
      description: '${AlertDescriptionHeader}\nThis could indicate a lag or poor performance for user Profiles or Apps using MSIX App Attach.\nThis is a total latency from end to end between the Host VM and Storage to include network.\nFor additional details on troubleshooting see:\n"https://learn.microsoft.com/en-us/azure/storage/files/storage-troubleshooting-files-performance#very-high-latency-for-requests"'
      severity: 1
      evaluationFrequency: 'PT15M'
      windowSize: 'PT15M'
      criteria: {
        allOf: [
          {
            threshold: 100
            name: 'Metric1'
            metricName: 'SuccessE2ELatency'
            operator: 'GreaterThan'
            timeAggregation: 'Average'
            criterionType: 'StaticThresholdCriterion'
          }
        ]
        'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      }
      targetResourceType: 'Microsoft.Storage/storageAccounts'
    }
    {
      name: '${AlertNamePrefix}Storage-Azure Files Availability'
      displayName: '${AlertNamePrefix}Storage-Azure Files Availability'
      description: '${AlertDescriptionHeader}\nThis could indicate storage is unavailable for user Profiles or Apps using MSIX App Attach.'
      severity: 1
      evaluationFrequency: 'PT5M'
      windowSize: 'PT5M'
      criteria: {
        allOf: [
          {
            threshold: 99
            name: 'Metric1'
            metricName: 'Availability'
            operator: 'LessThanOrEqual'
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
      name: '${AlertNamePrefix}Storage-Possible Throttling Due to High IOPs'
      displayName: '${AlertNamePrefix}Storage-Possible Throttling Due to High IOPs'
      description: '${AlertDescriptionHeader}\nThis indicates you may be maxing out the allowed IOPs.\nhttps://docs.microsoft.com/en-us/azure/storage/files/storage-troubleshooting-files-performance#how-to-create-an-alert-if-a-file-share-is-throttled'
      severity: 2
      evaluationFrequency: 'PT15M'
      windowSize: 'PT15M'
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
      name: '${AlertNamePrefix}Storage-Low Space on ANF Share-15 Percent Remaining'
      displayName: '${AlertNamePrefix}Storage-Low Space on ANF Share-15% Remaining'
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
      name: '${AlertNamePrefix}Storage-Low Space on ANF Share-5 Percent Remaining'
      displayName: '${AlertNamePrefix}Storage-Low Space on ANF Share-5% Remaining'
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
      name: '${AlertNamePrefix}VM-High CPU 85 Percent'
      displayName: '${AlertNamePrefix}VM-High CPU 85%'
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
      name: '${AlertNamePrefix}VM-High CPU 95 Percent'
      displayName: '${AlertNamePrefix}VM-High CPU 95%'
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
      name: '${AlertNamePrefix}VM-Available Memory Less Than 2GB'
      displayName: '${AlertNamePrefix}VM-Available Memory Less Than 2GB'
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
      name: '${AlertNamePrefix}VM-Available Memory Less Than 1GB'
      displayName: '${AlertNamePrefix}VM-Available Memory Less Than 1GB'
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
      name: '${AlertNamePrefix}HostPool-UsageAbove80percent'
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

var ActivityLogAlerts = [
  {
    name: '${AlertNamePrefix}SerivceHealth-Service Issue'
    displayName: '${AlertNamePrefix}SerivceHealth-Serivice Issue'
    description: AlertDescriptionHeader
    anyof: [
      {
        field: 'properties.incidentType'
        equals: 'Incident'
      }
    ]
  }
  {
    name: '${AlertNamePrefix}SerivceHealth-Planned Maintenance'
    displayName: '${AlertNamePrefix}SerivceHealth-Planned Maintenance'
    description: AlertDescriptionHeader
    anyOf: [
      {
        field: 'properties.incidentType'
        equals: 'Maintenance'
      }
    ]
  }
  {
    name: '${AlertNamePrefix}SerivceHealth-Health Advisory'
    displayName: '${AlertNamePrefix}SerivceHealth-HealthAdvisory'
    description: AlertDescriptionHeader
    anyOf: [
      {
        field: 'properties.incidentType'
        equals: 'Informational'
      }
      {
        field: 'properties.incidentType'
        equals: 'ActionRequired'
      }
    ]
  }
  {
    name: '${AlertNamePrefix}SerivceHealth-Security'
    displayName: '${AlertNamePrefix}SerivceHealth-Security'
    description: AlertDescriptionHeader
    anyOf: [
      {
        field: 'properties.incidentType'
        equals: 'Security'
      }
    ]
  }
]

resource resourceGroupAVDMetrics 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: ((!empty(UserResourceGroup))) ? UserResourceGroup : ResourceGroupName
  tags: Tags
  location: Location
}

//  Function App Role required for Custom Metrics write - Removed until in US Gov and GA
/* resource roleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' = {
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
} */

module resources 'modules/resources.bicep' = {
  name: 'MonitoringResourcesDeployment'
  scope: resourceGroupAVDMetrics
  params: {
    ActivityLogAlerts: ActivityLogAlerts
    AutomationAccountName: AutomationAccountName
    DistributionGroup: DistributionGroup
    //FunctionAppName: FunctionAppName
    //HostingPlanName: HostingPlanName
    Location: Location
    LogAnalyticsWorkspaceResourceId: LogAnalyticsWorkspaceResourceId
    LogAlerts: LogAlerts
    LogicAppName: LogicAppName
    MetricAlerts: MetricAlerts
    RunbookNameGetStorage: RunbookNameGetStorage
    RunbookNameGetHostPool: RunbookNameGetHostPool
    RunbookScriptGetStorage: RunbookScriptGetStorage
    RunbookScriptGetHostPool: RunbookScriptGetHostPool
    ScriptsRepositoryUri: ScriptsRepositoryUri
    SessionHostsResourceGroupIds: SessionHostsResourceGroupIds
    StorageAccountResourceIds: StorageAccountResourceIds
    ActionGroupName: ActionGroupName
    ANFVolumeResourceIds: ANFVolumeResourceIds
    Tags: Tags
  }
}

resource roleAssignment_Subscription 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for Role in items(RoleAssignments): {
  name: guid(subscription().id, AutomationAccountName, Role.value.Name)
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', Role.value.GUID)
    principalId: resources.outputs.automationAccountPrincipalId
    principalType: 'ServicePrincipal'
  }
}]

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
