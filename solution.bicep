targetScope = 'subscription'

/*   TO BE ADDED
@description('Determine if you would like to set all deployed alerts to auto-resolve.')
param SetAutoResolve bool = true

@description('Determine if you would like to enable all the alerts after deployment.')
param SetEnabled bool = false
 */

@description('Location of needed scripts to deploy solution.')
param _ArtifactsLocation string = 'https://raw.githubusercontent.com/JCoreMS/AVDAlerts/main/deploySubscription/scripts/'

@description('SaS token if needed for script location.')
@secure()
param _ArtifactsLocationSasToken string

@description('Alert Name Prefix (Dash will be added after prefix for you.)')
param AlertNamePrefix string = 'AVD'

@description('The Distribution Group that will receive email alerts for AVD.')
param DistributionGroup string

@allowed([
  'd'
  'p'
  't'
])
@description('The environment is which these resources will be deployed, i.e. Test, Production, Development.')
param Environment string = 't'

@description('Comma seperated string of Host Pool IDs')
param HostPools array = []

@description('Azure Region for Resources.')
param Location string

@description('The Resource ID for the Log Analytics Workspace.')
param LogAnalyticsWorkspaceResourceId string

@description('Resource Group to deploy the Alerts Solution in.')
param ResourceGroupName string

@description('The Resource Group ID for the AVD session host VMs.')
param SessionHostsResourceGroupIds array = []

@description('The Resource IDs for the Azure Files Storage Accounts used for FSLogix profile storage.')
param StorageAccountResourceIds array = []

@description('The Resource IDs for the Azure NetApp Volumes used for FSLogix profile storage.')
param ANFVolumeResourceIds array = []

param Tags object = {}

var ActionGroupName = 'ag-avdmetrics-${Environment}-${Location}'
var AlertDescriptionHeader = 'Automated AVD Alert Deployment Solution (v2.0.0)\n'
var AutomationAccountName = 'aa-avdmetrics-${Environment}-${Location}'
var HostPoolSubIdsAll = [for item in HostPools : split(item, '/')[2]]
var HostPoolSubIds = union(HostPoolSubIdsAll,[])
var HostPoolRGsAll = [for item in HostPools : split(item, '/')[4]]
var HostPoolRGs = union(HostPoolRGsAll,[])
var LogicAppName = 'la-avdmetrics-${Environment}-${Location}'

//var ResourceGroupName = 'rg-avdmetrics-${Environment}-${Location}'
var RunbookNameGetStorage = 'AvdStorageLogData'
var RunbookNameGetHostPool = 'AvdHostPoolLogData'
var RunbookScriptGetStorage = 'Get-StorAcctInfov2.ps1'
var RunbookScriptGetHostPool = 'Get-HostPoolInfo.ps1'
var SessionHostRGsAll = [for item in SessionHostsResourceGroupIds : split(item, '/')[4]]
var SessionHostRGs = union(SessionHostRGsAll,[])
var StorAcctRGsAll = [for item in StorageAccountResourceIds: split(item, '/')[4]]
var StorAcctRGs = union(StorAcctRGsAll,[])
var UsrManagedIdentityName = 'id-ds-avdAlerts-Deployment'

var DesktopReadRoleRGs = union(HostPoolRGs, SessionHostRGs)

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
// '49a72310-ab8d-41df-bbb0-79b649203868'  // Desktop Virtualization Reader
// '17d1049b-9a84-46fb-8f53-869881c3d3ab'  // Storage Account Contributor
// '92aaf0da-9dab-42b6-94a3-d43ce8d16293'  // Log Analtyics Contributor - allows writing to workspace for Host Pool and Storage Logic Apps

var LogAlertsHostPool = [
  { // Based on Runbook script Output to LAW
    name: '${AlertNamePrefix}-HostPool-Capacity-85Percent (xHostPoolNamex)'
    displayName: '${AlertNamePrefix}-HostPool-Capacity 85% (xHostPoolNamex)'
    description: '${AlertDescriptionHeader}This alert is based on the Action Account and Runbook that populates the Log Analytics specificed with the AVD Metrics Deployment Solution.\n-->Last Number in the string is the Percentage Remaining for the Host Pool\nOutput is:\nHostPoolName|ResourceGroup|Type|MaxSessionLimit|NumberHosts|TotalUsers|DisconnectedUser|ActiveUsers|SessionsAvailable|HostPoolPercentageLoad'
    severity: 2
    evaluationFrequency: 'PT1M'
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
          | where HostPoolName == 'xHostPoolNamex'
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
    name: '${AlertNamePrefix}-HostPool-Capacity-50Percent (xHostPoolNamex)'
    displayName: '${AlertNamePrefix}-HostPool-Capacity 50% (xHostPoolNamex)'
    description: '${AlertDescriptionHeader}This alert is based on the Action Account and Runbook that populates the Log Analytics specificed with the AVD Metrics Deployment Solution.\n-->Last Number in the string is the Percentage Remaining for the Host Pool\nOutput is:\nHostPoolName|ResourceGroup|Type|MaxSessionLimit|NumberHosts|TotalUsers|DisconnectedUser|ActiveUsers|SessionsAvailable|HostPoolPercentageLoad'
    severity: 3
    evaluationFrequency: 'PT1M'
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
          | where HostPoolName == 'xHostPoolNamex'         
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
    name: '${AlertNamePrefix}-HostPool-Capacity-95Percent (xHostPoolNamex)'
    displayName: '${AlertNamePrefix}-HostPool-Capacity 95% (xHostPoolNamex)'
    description: '${AlertDescriptionHeader}This alert is based on the Action Account and Runbook that populates the Log Analytics specificed with the AVD Metrics Deployment Solution.\n-->Last Number in the string is the Percentage Remaining for the Host Pool\nOutput is:\nHostPoolName|ResourceGroup|Type|MaxSessionLimit|NumberHosts|TotalUsers|DisconnectedUser|ActiveUsers|SessionsAvailable|HostPoolPercentageLoad'
    severity: 1
    evaluationFrequency: 'PT1M'
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
          | where HostPoolName == 'xHostPoolNamex'        
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
  {
    name: '${AlertNamePrefix}-HostPool-No Resources Available (xHostPoolNamex)'
    displayName: '${AlertNamePrefix}-HostPool-No Resources Available (xHostPoolNamex)'
    description: AlertDescriptionHeader
    severity: 1
    evaluationFrequency: 'PT15M'
    windowSize: 'PT15M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: 'WVDConnections \n| where TimeGenerated > ago (15m) \n| where _ResourceId contains "xHostPoolNamex" \n| project-away TenantId,SourceSystem  \n| summarize arg_max(TimeGenerated, *), StartTime =  min(iff(State== \'Started\', TimeGenerated , datetime(null) )), ConnectTime = min(iff(State== \'Connected\', TimeGenerated , datetime(null) ))   by CorrelationId  \n| join kind=leftouter (WVDErrors\n    |summarize Errors=makelist(pack(\'Code\', Code, \'CodeSymbolic\', CodeSymbolic, \'Time\', TimeGenerated, \'Message\', Message ,\'ServiceError\', ServiceError, \'Source\', Source)) by CorrelationId  \n    ) on CorrelationId\n| join kind=leftouter (WVDCheckpoints\n    | summarize Checkpoints=makelist(pack(\'Time\', TimeGenerated, \'Name\', Name, \'Parameters\', Parameters, \'Source\', Source)) by CorrelationId  \n    | mv-apply Checkpoints on (  \n        order by todatetime(Checkpoints[\'Time\']) asc\n        | summarize Checkpoints=makelist(Checkpoints)\n        )\n    ) on CorrelationId  \n| project-away CorrelationId1, CorrelationId2  \n| order by TimeGenerated desc\n| where Errors[0].CodeSymbolic == "ConnectionFailedNoHealthyRdshAvailable"\n\n'
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
    name: '${AlertNamePrefix}-HostPool-Disconnected User over 24 Hours (xHostPoolNamex)'
    displayName: '${AlertNamePrefix}-HostPool-Disconnected User over 24 Hours (xHostPoolNamex)'
    description: AlertDescriptionHeader
    severity: 2
    evaluationFrequency: 'PT1H'
    windowSize: 'PT1H'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: '// Session duration \n// Lists users by session duration in the last 24 hours. \n// The "State" provides information on the connection stage of an activity.\n// The delta between "Connected" and "Completed" provides the connection time for a specific connection.\nWVDConnections \n| where TimeGenerated > ago(24h) \n| where State == "Connected" \n| where _ResourceId contains "xHostPoolNamex" \n| project CorrelationId , UserName, ConnectionType, StartTime=TimeGenerated, SessionHostName\n| join (WVDConnections  \n    | where State == "Completed"  \n    | project EndTime=TimeGenerated, CorrelationId)  \n    on CorrelationId  \n| project Duration = EndTime - StartTime, ConnectionType, UserName, SessionHostName\n| where Duration >= timespan(24:00:00)\n| sort by Duration desc'
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
    name: '${AlertNamePrefix}-HostPool-Disconnected User over 72 Hours (xHostPoolNamex)'
    displayName: '${AlertNamePrefix}-HostPool-Disconnected User over 72 Hours (xHostPoolNamex)'
    description: AlertDescriptionHeader
    severity: 1
    evaluationFrequency: 'PT1H'
    windowSize: 'PT1H'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: '// Session duration \n// Lists users by session duration in the last 24 hours. \n// The "State" provides information on the connection stage of an activity.\n// The delta between "Connected" and "Completed" provides the connection time for a specific connection.\nWVDConnections \n| where TimeGenerated > ago(24h) \n| where State == "Connected" \n| where _ResourceId contains "xHostPoolNamex"  \n| project CorrelationId , UserName, ConnectionType, StartTime=TimeGenerated, SessionHostName\n| join (WVDConnections  \n    | where State == "Completed"  \n    | project EndTime=TimeGenerated, CorrelationId)  \n    on CorrelationId  \n| project Duration = EndTime - StartTime, ConnectionType, UserName, SessionHostName\n| where Duration >= timespan(72:00:00)\n| sort by Duration desc'
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
    name: '${AlertNamePrefix}-HostPool-VM-Local Disk Free Space 10 Percent (xHostPoolNamex)'
    displayName: '${AlertNamePrefix}-HostPool-VM-Local Disk Free Space 10 Percent (xHostPoolNamex)'
    description: AlertDescriptionHeader
    severity: 2
    evaluationFrequency: 'PT15M'
    windowSize: 'PT15M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: '''
          Perf
          | where TimeGenerated > ago(15m)
          | where ObjectName == "LogicalDisk" and CounterName == "% Free Space"
          | where InstanceName !contains "D:"
          | where InstanceName  !contains "_Total"| where CounterValue <= 10.00
          | parse _ResourceId with "/subscriptions/" subscription "/resourcegroups/" ResourceGroup "/providers/microsoft.compute/virtualmachines/" ComputerName
          | project ComputerName, CounterValue, subscription, ResourceGroup, TimeGenerated
          | join kind = leftouter
          (
              WVDAgentHealthStatus
              | where TimeGenerated > ago(15m)
              | where _ResourceId contains "xHostPoolNamex"
              | parse _ResourceId with "/subscriptions/" subscriptionAgentHealth "/resourcegroups/" ResourceGroupAgentHealth "/providers/microsoft.desktopvirtualization/hostpools/" HostPool
              | parse SessionHostResourceId with "/subscriptions/" VMsubscription "/resourceGroups/" VMresourceGroup "/providers/Microsoft.Compute/virtualMachines/" ComputerName
              | project VMresourceGroup, ComputerName, HostPool
              ) on ComputerName
          '''
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'ComputerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'VMresourceGroup'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'HostPool'
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
    name: '${AlertNamePrefix}-HostPool-VM-Local Disk Free Space 5 Percent (xHostPoolNamex)'
    displayName: '${AlertNamePrefix}-HostPool-VM-Local Disk Free Space 5 Percent (xHostPoolNamex)'
    description: AlertDescriptionHeader
    severity: 1
    evaluationFrequency: 'PT15M'
    windowSize: 'PT15M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: '''
          Perf
          | where TimeGenerated > ago(15m)
          | where ObjectName == "LogicalDisk" and CounterName == "% Free Space"
          | where InstanceName !contains "D:"
          | where InstanceName  !contains "_Total"| where CounterValue <= 5.00
          | parse _ResourceId with "/subscriptions/" subscription "/resourcegroups/" ResourceGroup "/providers/microsoft.compute/virtualmachines/" ComputerName
          | project ComputerName, CounterValue, subscription, ResourceGroup, TimeGenerated
          | join kind = leftouter
          (
              WVDAgentHealthStatus
              | where TimeGenerated > ago(15m)
              | where _ResourceId contains "xHostPoolNamex"
              | parse _ResourceId with "/subscriptions/" subscriptionAgentHealth "/resourcegroups/" ResourceGroupAgentHealth "/providers/microsoft.desktopvirtualization/hostpools/" HostPool
              | parse SessionHostResourceId with "/subscriptions/" VMsubscription "/resourceGroups/" VMresourceGroup "/providers/Microsoft.Compute/virtualMachines/" ComputerName
              | project VMresourceGroup, ComputerName, HostPool
              ) on ComputerName
          '''
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'ComputerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'VMresourceGroup'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'HostPool'
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
    name: '${AlertNamePrefix}-HostPool-VM-FSLogix Profile-LessThan5PercentFree (xHostPoolNamex)'
    displayName: '${AlertNamePrefix}-HostPool-VM-FSLogix Profile Less Than 5% Free Space (xHostPoolNamex)'
    description: AlertDescriptionHeader
    severity: 2
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: 'Event\n| where EventLog == "Microsoft-FSLogix-Apps/Admin"\n| where EventLevelName == "Warning"\n| where EventID == 34\n| where _ResourceId contains "xHostPoolNamex"\n| parse _ResourceId with "/subscriptions/" subscription "/resourcegroups/" ResourceGroup "/providers/microsoft.compute/virtualmachines/" ComputerName\n| project ComputerName, RenderedDescription, subscription, ResourceGroup, TimeGenerated\n| join kind = leftouter\n    (\n    WVDAgentHealthStatus\n   // | where TimeGenerated > ago(15m)\n    | parse _ResourceId with "/subscriptions/" subscriptionAgentHealth "/resourcegroups/" ResourceGroupAgentHealth "/providers/microsoft.desktopvirtualization/hostpools/" HostPool\n    | parse SessionHostResourceId with "/subscriptions/" VMsubscription "/resourceGroups/" VMresourceGroup "/providers/Microsoft.Compute/virtualMachines/" ComputerName\n    | project VMresourceGroup, ComputerName, HostPool\n    )\n    on ComputerName\n\n'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'ComputerName'
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
            {
              name: 'VMresourceGroup'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'HostPool'
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
    name: '${AlertNamePrefix}-HostPool-VM-FSLogix Profile-LessThan2PercentFree (xHostPoolNamex)'
    displayName: '${AlertNamePrefix}-HostPool-VM-FSLogix Profile Less Than 2% Free Space (xHostPoolNamex)'
    description: AlertDescriptionHeader
    severity: 1
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: 'Event\n| where EventLog == "Microsoft-FSLogix-Apps/Admin"\n| where EventLevelName == "Error"\n| where EventID == 33\n| where _ResourceId contains "xHostPoolNamex"\n| parse _ResourceId with "/subscriptions/" subscription "/resourcegroups/" ResourceGroup "/providers/microsoft.compute/virtualmachines/" ComputerName\n| project ComputerName, RenderedDescription, subscription, ResourceGroup, TimeGenerated\n| join kind = leftouter\n    (\n    WVDAgentHealthStatus\n   // | where TimeGenerated > ago(15m)\n    | parse _ResourceId with "/subscriptions/" subscriptionAgentHealth "/resourcegroups/" ResourceGroupAgentHealth "/providers/microsoft.desktopvirtualization/hostpools/" HostPool\n    | parse SessionHostResourceId with "/subscriptions/" VMsubscription "/resourceGroups/" VMresourceGroup "/providers/Microsoft.Compute/virtualMachines/" ComputerName\n    | project VMresourceGroup, ComputerName, HostPool\n    )\n    on ComputerName\n\n'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'ComputerName'
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
            {
              name: 'VMresourceGroup'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'HostPool'
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
    name: '${AlertNamePrefix}-HostPool-VM-FSLogix Profile-NetworkIssue (xHostPoolNamex)'
    displayName: '${AlertNamePrefix}-HostPool-VM-FSLogix Profile Failed due to Network Issue (xHostPoolNamex)'
    description: AlertDescriptionHeader
    severity: 1
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: 'Event\n| where EventLog == "Microsoft-FSLogix-Apps/Admin"\n| where EventLevelName == "Error"\n| where EventID == 43\n| where _ResourceId contains "xHostPoolNamex"\n| parse _ResourceId with "/subscriptions/" subscription "/resourcegroups/" ResourceGroup "/providers/microsoft.compute/virtualmachines/" ComputerName\n| project ComputerName, RenderedDescription, subscription, ResourceGroup, TimeGenerated\n| join kind = leftouter\n    (\n    WVDAgentHealthStatus\n   // | where TimeGenerated > ago(15m)\n    | parse _ResourceId with "/subscriptions/" subscriptionAgentHealth "/resourcegroups/" ResourceGroupAgentHealth "/providers/microsoft.desktopvirtualization/hostpools/" HostPool\n    | parse SessionHostResourceId with "/subscriptions/" VMsubscription "/resourceGroups/" VMresourceGroup "/providers/Microsoft.Compute/virtualMachines/" ComputerName\n    | project VMresourceGroup, ComputerName, HostPool\n    )\n    on ComputerName\n\n'

          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'ComputerName'
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
            {
              name: 'VMresourceGroup'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'HostPool'
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
    name: '${AlertNamePrefix}-HostPool-VM-FSLogix Profile-FailedAttachVHD (xHostPoolNamex)'
    displayName: '${AlertNamePrefix}-HostPool-VM-FSLogix Profile Disk Failed to Attach (xHostPoolNamex)'
    description: AlertDescriptionHeader
    severity: 1
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: 'Event\n| where EventLog == "Microsoft-FSLogix-Apps/Admin"\n| where EventLevelName == "Error"\n| where EventID == 52 or EventID == 40\n| where _ResourceId contains "xHostPoolNamex"\n| parse _ResourceId with "/subscriptions/" subscription "/resourcegroups/" ResourceGroup "/providers/microsoft.compute/virtualmachines/" ComputerName\n| project ComputerName, RenderedDescription, subscription, ResourceGroup, TimeGenerated\n| join kind = leftouter\n    (\n    WVDAgentHealthStatus\n   // | where TimeGenerated > ago(15m)\n    | parse _ResourceId with "/subscriptions/" subscriptionAgentHealth "/resourcegroups/" ResourceGroupAgentHealth "/providers/microsoft.desktopvirtualization/hostpools/" HostPool\n    | parse SessionHostResourceId with "/subscriptions/" VMsubscription "/resourceGroups/" VMresourceGroup "/providers/Microsoft.Compute/virtualMachines/" ComputerName\n    | project VMresourceGroup, ComputerName, HostPool\n    )\n    on ComputerName\n\n'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'ComputerName'
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
            {
              name: 'VMresourceGroup'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'HostPool'
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
    name: '${AlertNamePrefix}-HostPool-VM-FSLogix Profile-SerivceDisabled (xHostPoolNamex)'
    displayName: '${AlertNamePrefix}-HostPool-VM-FSLogix Profile Service Disabled (xHostPoolNamex)'
    description: AlertDescriptionHeader
    severity: 1
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: 'Event\n| where EventLog == "Microsoft-FSLogix-Apps/Admin"\n| where EventLevelName == "Warning"\n| where EventID == 60\n| where _ResourceId contains "xHostPoolNamex"\n| parse _ResourceId with "/subscriptions/" subscription "/resourcegroups/" ResourceGroup "/providers/microsoft.compute/virtualmachines/" ComputerName\n| project ComputerName, RenderedDescription, subscription, ResourceGroup, TimeGenerated\n| join kind = leftouter\n    (\n    WVDAgentHealthStatus\n   // | where TimeGenerated > ago(15m)\n    | parse _ResourceId with "/subscriptions/" subscriptionAgentHealth "/resourcegroups/" ResourceGroupAgentHealth "/providers/microsoft.desktopvirtualization/hostpools/" HostPool\n    | parse SessionHostResourceId with "/subscriptions/" VMsubscription "/resourceGroups/" VMresourceGroup "/providers/Microsoft.Compute/virtualMachines/" ComputerName\n    | project VMresourceGroup, ComputerName, HostPool\n    )\n    on ComputerName\n\n'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'ComputerName'
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
            {
              name: 'VMresourceGroup'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'HostPool'
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
    name: '${AlertNamePrefix}-HostPool-VM-FSLogix Profile-DiskCompactFailed (xHostPoolNamex)'
    displayName: '${AlertNamePrefix}-HostPool-VM-FSLogix Profile Disk Compaction Failed (xHostPoolNamex)'
    description: AlertDescriptionHeader
    severity: 2
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: 'Event\n| where EventLog == "Microsoft-FSLogix-Apps/Admin"\n| where EventLevelName == "Error"\n| where EventID == 62 or EventID == 63\n| where _ResourceId contains "xHostPoolNamex"\n| parse _ResourceId with "/subscriptions/" subscription "/resourcegroups/" ResourceGroup "/providers/microsoft.compute/virtualmachines/" ComputerName\n| project ComputerName, RenderedDescription, subscription, ResourceGroup, TimeGenerated\n| join kind = leftouter\n    (\n    WVDAgentHealthStatus\n   // | where TimeGenerated > ago(15m)\n    | parse _ResourceId with "/subscriptions/" subscriptionAgentHealth "/resourcegroups/" ResourceGroupAgentHealth "/providers/microsoft.desktopvirtualization/hostpools/" HostPool\n    | parse SessionHostResourceId with "/subscriptions/" VMsubscription "/resourceGroups/" VMresourceGroup "/providers/Microsoft.Compute/virtualMachines/" ComputerName\n    | project VMresourceGroup, ComputerName, HostPool\n    )\n    on ComputerName\n\n'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'ComputerName'
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
            {
              name: 'VMresourceGroup'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'HostPool'
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
    name: '${AlertNamePrefix}-HostPool-VM-FSLogix Profile-DiskInUse (xHostPoolNamex)'
    displayName: '${AlertNamePrefix}-HostPool-VM-FSLogix Profile Disk Attached to another VM (xHostPoolNamex)'
    description: AlertDescriptionHeader
    severity: 2
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: 'Event\n| where EventLog == "Microsoft-FSLogix-Apps/Operational"\n| where EventLevelName == "Warning"\n| where EventID == 51\n| where _ResourceId contains "xHostPoolNamex"\n| parse _ResourceId with "/subscriptions/" subscription "/resourcegroups/" ResourceGroup "/providers/microsoft.compute/virtualmachines/" ComputerName\n| project ComputerName, RenderedDescription, subscription, ResourceGroup, TimeGenerated\n| join kind = leftouter\n    (\n    WVDAgentHealthStatus\n   // | where TimeGenerated > ago(15m)\n    | parse _ResourceId with "/subscriptions/" subscriptionAgentHealth "/resourcegroups/" ResourceGroupAgentHealth "/providers/microsoft.desktopvirtualization/hostpools/" HostPool\n    | parse SessionHostResourceId with "/subscriptions/" VMsubscription "/resourceGroups/" VMresourceGroup "/providers/Microsoft.Compute/virtualMachines/" ComputerName\n    | project VMresourceGroup, ComputerName, HostPool\n    )\n    on ComputerName\n\n'
          timeAggregation: 'Count'
          dimensions: [
            {
              name: 'ComputerName'
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
            {
              name: 'VMresourceGroup'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'HostPool'
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
    name: '${AlertNamePrefix}-HostPool-VM-Health Check Failure (xHostPoolNamex)'
    displayName: '${AlertNamePrefix}-HostPool-VM-Health Check Failure (xHostPoolNamex)'
    description: '${AlertDescriptionHeader}VM is available for use but one of the dependent resources is in a failed state for hostpool xHostPoolNamex'
    severity: 1
    evaluationFrequency: 'PT15M'
    windowSize: 'PT15M'
    overrideQueryTimeRange: 'P2D'
    criteria: {
      allOf: [
        {
          query: '// HealthChecks of SessionHost \n// Renders a summary of SessionHost health status. \nlet MapToDesc = (idx: long) {\n    case(idx == 0, "DomainJoin",\n    idx == 1, "DomainTrust",\n    idx == 2, "FSLogix",\n    idx == 3, "SxSStack",\n    idx == 4, "URLCheck",\n    idx == 5, "GenevaAgent",\n    idx == 6, "DomainReachable",\n    idx == 7, "WebRTCRedirector",\n    idx == 8, "SxSStackEncryption",\n    idx == 9, "IMDSReachable",\n    idx == 10, "MSIXPackageStaging",\n    "InvalidIndex")\n};\nWVDAgentHealthStatus\n| where TimeGenerated > ago(10m)\n| where Status != \'Available\'\n| where AllowNewSessions = True\n| extend CheckFailed = parse_json(SessionHostHealthCheckResult)\n| mv-expand CheckFailed\n| where CheckFailed.AdditionalFailureDetails.ErrorCode != 0\n| extend HealthCheckName = tolong(CheckFailed.HealthCheckName)\n| extend HealthCheckResult = tolong(CheckFailed.HealthCheckResult)\n| extend HealthCheckDesc = MapToDesc(HealthCheckName)\n| where HealthCheckDesc != \'InvalidIndex\'\n| where _ResourceId contains "xHostPoolNamex"\n| parse _ResourceId with "/subscriptions/" subscription "/resourcegroups/" HostPoolResourceGroup "/providers/microsoft.desktopvirtualization/hostpools/" HostPool\n| parse SessionHostResourceId with "/subscriptions/" HostSubscription "/resourceGroups/" SessionHostRG " /providers/Microsoft.Compute/virtualMachines/" SessionHostName\n'
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
            {
              name: 'HostPool'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'SessionHostRG'
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
]

var LogAlerts = [
  { // Based on Runbook script Output to LAW
    name: '${AlertNamePrefix}-Storage-Low Space on Azure File Share-15 Percent Remaining'
    displayName: '${AlertNamePrefix}-Storage-Low Space on Azure File Share-15% Remaining'
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
    name: '${AlertNamePrefix}-Storage-Low Space on Azure File Share-5 Percent Remaining'
    displayName: '${AlertNamePrefix}-Storage-Low Space on Azure File Share-5% Remaining'
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
]
var MetricAlerts = {
  storageAccounts: [
    {
      name: '${AlertNamePrefix}-Storage-Over 50ms Latency for Storage Acct'
      displayName: '${AlertNamePrefix}-Storage-Over 50ms Latency for Storage Acct'
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
      name: '${AlertNamePrefix}-Storage-Over 100ms Latency for Storage Acct'
      displayName: '${AlertNamePrefix}-Storage-Over 100ms Latency for Storage Acct'
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
      name: '${AlertNamePrefix}-Storage-Over 50ms Latency Between Client-Storage'
      displayName: '${AlertNamePrefix}-Storage-Over 50ms Latency Between Client-Storage'
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
      name: '${AlertNamePrefix}-Storage-Over 100ms Latency Between Client-Storage'
      displayName: '${AlertNamePrefix}-Storage-Over 100ms Latency Between Client-Storage'
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
      name: '${AlertNamePrefix}-Storage-Azure Files Availability'
      displayName: '${AlertNamePrefix}-Storage-Azure Files Availability'
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
      name: '${AlertNamePrefix}-Storage-Possible Throttling Due to High IOPs'
      displayName: '${AlertNamePrefix}-Storage-Possible Throttling Due to High IOPs'
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
      name: '${AlertNamePrefix}-Storage-Low Space on ANF Share-15 Percent Remaining'
      displayName: '${AlertNamePrefix}-Storage-Low Space on ANF Share-15% Remaining'
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
      name: '${AlertNamePrefix}-Storage-Low Space on ANF Share-5 Percent Remaining'
      displayName: '${AlertNamePrefix}-Storage-Low Space on ANF Share-5% Remaining'
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
      name: '${AlertNamePrefix}-HostPool-VM-High CPU 85 Percent (xHostPoolNamex)'
      displayName: '${AlertNamePrefix}-HostPool-VM-High CPU 85% (xHostPoolNamex)'
      description: AlertDescriptionHeader
      severity: 2
      evaluationFrequency: 'PT1M'
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
      name: '${AlertNamePrefix}-HostPool-VM-High CPU 95 Percent (xHostPoolNamex)'
      displayName: '${AlertNamePrefix}-HostPool-VM-High CPU 95% (xHostPoolNamex)'
      description: AlertDescriptionHeader
      severity: 1
      evaluationFrequency: 'PT1M'
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
      name: '${AlertNamePrefix}-HostPool-VM-Available Memory Less Than 2GB (xHostPoolNamex)'
      displayName: '${AlertNamePrefix}-HostPool-VM-Available Memory Less Than 2GB (xHostPoolNamex)'
      description: AlertDescriptionHeader
      severity: 2
      evaluationFrequency: 'PT1M'
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
      name: '${AlertNamePrefix}-HostPool-VM-Available Memory Less Than 1GB (xHostPoolNamex)'
      displayName: '${AlertNamePrefix}-HostPool-VM-Available Memory Less Than 1GB (xHostPoolNamex)'
      description: AlertDescriptionHeader
      severity: 1
      evaluationFrequency: 'PT1M'
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
      name: '${AlertNamePrefix}-HostPool-UsageAbove80percent'
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
    name: '${AlertNamePrefix}-SerivceHealth-Service Issue'
    displayName: '${AlertNamePrefix}-SerivceHealth-Serivice Issue'
    description: AlertDescriptionHeader
    anyof: [
      {
        field: 'properties.incidentType'
        equals: 'Incident'
      }
    ]
  }
  {
    name: '${AlertNamePrefix}-SerivceHealth-Planned Maintenance'
    displayName: '${AlertNamePrefix}-SerivceHealth-Planned Maintenance'
    description: AlertDescriptionHeader
    anyOf: [
      {
        field: 'properties.incidentType'
        equals: 'Maintenance'
      }
    ]
  }
  {
    name: '${AlertNamePrefix}-SerivceHealth-Health Advisory'
    displayName: '${AlertNamePrefix}-SerivceHealth-HealthAdvisory'
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
    name: '${AlertNamePrefix}-SerivceHealth-Security'
    displayName: '${AlertNamePrefix}-SerivceHealth-Security'
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
  name: ResourceGroupName
  tags: contains(Tags, 'Microsoft.Resources/resourceGroups') ? Tags['Microsoft.Resources/resourceGroups'] : {}
  location: Location
}

module identities './modules/identities.bicep' = {
  name: 'linked_AutomtnAcct-${AutomationAccountName}'
  scope: resourceGroupAVDMetrics
  params: {
    AutomationAccountName: AutomationAccountName
    Location: Location
    LogAnalyticsWorkspaceResourceId: LogAnalyticsWorkspaceResourceId
    UsrManagedIdentityName: UsrManagedIdentityName
    Tags: Tags
  }
}

module roleAssignment_UsrIdDesktopRead './modules/roleAssignSub.bicep' = [for HostPoolId in HostPoolSubIds : {
  name: 'linked_UsrID-DS_${HostPoolId}'
  scope: subscription(HostPoolId)
  params: {
    AccountName: UsrManagedIdentityName
    Subscription: HostPoolId
    RoleDefinition: RoleAssignments.DesktopVirtualizationRead
    PrincipalId: identities.outputs.UsrIdentityPrincipalID
  }
  dependsOn: [
    identities
  ]
}]

module roleAssignment_AutoAcctDesktopRead './modules/roleAssignRG.bicep' = [for RG in DesktopReadRoleRGs: {
  scope: resourceGroup(RG)
  name: 'linked_DsktpRead_${RG}'
  params: {
    AccountName: AutomationAccountName
    ResourceGroup: RG
    RoleDefinition: RoleAssignments.DesktopVirtualizationRead
    PrincipalId: identities.outputs.AutomationAcctPrincipalID
  }
  dependsOn: [
    identities
  ]
}]

module roleAssignment_LogAnalytics './modules/roleAssignRG.bicep' = {
  scope: resourceGroup(split(LogAnalyticsWorkspaceResourceId, '/')[2], split(LogAnalyticsWorkspaceResourceId, '/')[4])
  name: 'linked_LogContrib_${split(LogAnalyticsWorkspaceResourceId, '/')[4]}'
  params: {
    AccountName: AutomationAccountName
    ResourceGroup: split(LogAnalyticsWorkspaceResourceId, '/')[4]
    RoleDefinition: RoleAssignments.DesktopVirtualizationRead
    PrincipalId: identities.outputs.AutomationAcctPrincipalID
  }
  dependsOn: [
    identities
  ]
}

module roleAssignment_Storage './modules/roleAssignRG.bicep' = [for StorAcctRG in StorAcctRGs: {
  scope: resourceGroup(StorAcctRG)
  name: 'linked_StorAcctContrib_${StorAcctRG}'
  params: {
    AccountName: AutomationAccountName
    ResourceGroup: StorAcctRG
    RoleDefinition: RoleAssignments.StoreAcctContrib
    PrincipalId: identities.outputs.AutomationAcctPrincipalID
  }
  dependsOn: [
    identities
  ]
}]

module metricsResources './modules/metricsResources.bicep' = {
  name: 'linked_MonitoringResourcesDeployment'
  scope: resourceGroupAVDMetrics
  params: {
    _ArtifactsLocation: _ArtifactsLocation
    _ArtifactsLocationSasToken: _ArtifactsLocationSasToken
    ActivityLogAlerts: ActivityLogAlerts
    AutomationAccountName: AutomationAccountName
    DistributionGroup: DistributionGroup
    HostPools: HostPools
    Location: Location
    LogAnalyticsWorkspaceResourceId: LogAnalyticsWorkspaceResourceId
    LogAlerts: LogAlerts
    LogAlertsHostPool: LogAlertsHostPool
    LogicAppName: LogicAppName
    MetricAlerts: MetricAlerts
    RunbookNameGetStorage: RunbookNameGetStorage
    RunbookNameGetHostPool: RunbookNameGetHostPool
    RunbookScriptGetStorage: RunbookScriptGetStorage
    RunbookScriptGetHostPool: RunbookScriptGetHostPool
    StorageAccountResourceIds: StorageAccountResourceIds
    ActionGroupName: ActionGroupName
    ANFVolumeResourceIds: ANFVolumeResourceIds
    Tags: Tags
    UsrAssignedId: identities.outputs.UsrIdentityID
  }
  dependsOn: [
    identities
  ]
}
