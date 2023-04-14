param _ArtifactsLocation string
@secure()
param _ArtifactsLocationSasToken string
param ActionGroupName string
param ActivityLogAlerts array
param ANFVolumeResourceIds array
param AutomationAccountName string
param DistributionGroup string
//param FunctionAppName string
//param HostingPlanName string
//param HostPoolResourceGroupNames array
param HostPools array
param Location string
param LogAnalyticsWorkspaceResourceId string
param LogAlerts array
param LogAlertsHostPool array
//param LogAnalyticsWorkspaceName string
param LogicAppName string
param MetricAlerts object
param RunbookNameGetStorage string
param RunbookNameGetHostPool string
param RunbookScriptGetStorage string
param RunbookScriptGetHostPool string
param ScriptsRepositoryUri string
param StorageAccountResourceIds array
param Tags object
param Timestamp string = utcNow('u')
param UsrAssignedId string



// var Environment = environment().name
var SubscriptionId = subscription().subscriptionId
var CloudEnvironment = environment().name
var AVDResIDsString = string(HostPools)
//var AVDResIDsQuotes = replace(AVDResIDsString, ',', '","')
var HostPoolsAsString = replace(replace(AVDResIDsString, '[', ''), ']', '')

resource actionGroup 'Microsoft.Insights/actionGroups@2019-06-01' = {
  name: ActionGroupName
  tags: contains(Tags, 'Microsoft.Insights/actionGroups') ? Tags['Microsoft.Insights/actionGroups'] : {}
  location: 'global'
  properties: {
    groupShortName: 'EmailAlerts'
    enabled: true
    emailReceivers: [
      {
        name: DistributionGroup
        emailAddress: DistributionGroup
        useCommonAlertSchema: true
      }
    ]
  }
}

resource deploymentScript_HP2VM 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'ds_GetHostPoolVMAssociation'
  location: Location
  tags: contains(Tags, 'Microsoft.Resources/deploymentScripts') ? Tags['Microsoft.Resources/deploymentScripts'] : {}
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${UsrAssignedId}': {}
    }
  }
  properties: {
    forceUpdateTag: Timestamp
    azPowerShellVersion: '7.1'
    arguments: '-AVDResourceIDs ${HostPoolsAsString}'
    primaryScriptUri: '${_ArtifactsLocation}dsHostPoolVMMap.ps1${_ArtifactsLocationSasToken}'
    timeout: 'PT2H'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}

module metricAlertsVMs 'metricAlertsVMs.bicep'= [for i in range(0, length(HostPools)) : {
  name: 'linked_VMMetricAlerts_${guid(HostPools[i])}'
  params: {
    HostPoolInfo: json(deploymentScript_HP2VM.properties.outputs.HostPoolInfo)[i]
    MetricAlerts: MetricAlerts
    Enabled: false
    AutoMitigate: false
    Location: Location
    ActionGroupId: actionGroup.id
    Tags: Tags
  }
}]


module storAccountMetric 'storAccountMetric.bicep' = [for i in range(0, length(StorageAccountResourceIds)): if(length(StorageAccountResourceIds)>0) {
  name: 'MetricAlert_StorageAccount_${split(StorageAccountResourceIds[i],'/')[8]}'
  params: {
    Location: Location
    StorageAccountResourceID: StorageAccountResourceIds[i]
    MetricAlertsStorageAcct: MetricAlerts.storageAccounts
    ActionGroupID: actionGroup.id
    Tags: Tags
  }
}]

module azureNetAppFilesMetric 'anfMetric.bicep' = [for i in range(0, length(ANFVolumeResourceIds)): if(length(ANFVolumeResourceIds)>0) {
  name: 'MetricAlert_ANF_${split(ANFVolumeResourceIds[i],'/')[12]}'
  params: {
    Location: Location
    ANFVolumeResourceID: ANFVolumeResourceIds[i]
    MetricAlertsANF: MetricAlerts.anf
    ActionGroupID: actionGroup.id
    Tags: Tags
  }
}]

// If Metric Namespace contains file services ; change scopes to append default
// module to loop through each scope time as it MUST be a single Resource ID
module fileServicesMetric 'fileservicsmetric.bicep' = [for i in range(0, length(StorageAccountResourceIds)): if(length(StorageAccountResourceIds)>0) {
  name: 'MetricAlert_FileServices_${i}'
  params: {
    Location: Location
    StorageAccountResourceID: StorageAccountResourceIds[i]
    MetricAlertsFileShares: MetricAlerts.fileShares
    ActionGroupID: actionGroup.id
    Tags: Tags
  }
}]


resource logAlertQueries 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = [for i in range(0, length(LogAlerts)): {
  name: LogAlerts[i].name
  location: Location
  tags: contains(Tags, 'Microsoft.Insights/scheduledQueryRules') ? Tags['Microsoft.Insights/scheduledQueryRules'] : {}
  properties: {
    actions: {
      actionGroups: [
        actionGroup.id
      ]
      customProperties: {}
    }
    criteria: LogAlerts[i].criteria
    displayName: LogAlerts[i].displayName
    description: LogAlerts[i].description
    enabled: false
    evaluationFrequency: LogAlerts[i].evaluationFrequency
    scopes: [
      LogAnalyticsWorkspaceResourceId
    ]
    severity: LogAlerts[i].severity
    windowSize: LogAlerts[i].windowSize
  }
}]

module logAlertHostPoolQueries 'hostPoolAlerts.bicep' = [for hostpool in HostPools : {
  name: 'linked_HostPoolAlerts-${guid(hostpool, subscription().id)}'
  params: {
    ActionGroupId: actionGroup.id
    HostPoolName: split(hostpool, '/')[8]
    Location: Location
    LogAlertsHostPool:LogAlertsHostPool 
    LogAnalyticsWorkspaceResourceId: LogAnalyticsWorkspaceResourceId
    Tags: {
    }
  }
}]


// Currently only deploys IF Cloud Environment is Azure Commercial Cloud
resource activityLogAlerts 'Microsoft.Insights/activityLogAlerts@2020-10-01' = [for i in range(0, length(ActivityLogAlerts)): if(CloudEnvironment == 'AzureCloud') {
  name: ActivityLogAlerts[i].name
  location: 'Global'
  tags: contains(Tags, 'Microsoft.Insights/activityLogAlerts') ? Tags['Microsoft.Insights/activityLogAlerts'] : {}

  properties: {
    scopes: [
      '/subscriptions/${SubscriptionId}'
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'ServiceHealth'
        }
        {
          anyOf: ActivityLogAlerts[i].anyof
        }
        {
          field: 'properties.impactedServices[*].ServiceName'
          containsAny: [
            'Windows Virtual Desktop'
          ]
        }
        {
          field: 'properties.impactedServices[*].ImpactedRegions[*].RegionName'
          containsAny: [
            Location
          ]
        }
      ]
    }
    actions: {
      actionGroups: [
        {
        actionGroupId: actionGroup.id
        }
      ]
    }
    description: ActivityLogAlerts[i].description
    enabled: false
  }
}]


module logicApp_Storage './logicApp_Storage.bicep' = if(length(StorageAccountResourceIds)>0) {
  name: 'LogicApp_Storage'
  params: {
    AutomationAccountName: AutomationAccountName
    CloudEnvironment: CloudEnvironment
    Location: Location
    LogicAppName: '${LogicAppName}-Storage'
    RunbookNameGetStorage: RunbookNameGetStorage
    RunbookURI: '${ScriptsRepositoryUri}${RunbookScriptGetStorage}'
    StorageAccountResourceIds: StorageAccountResourceIds
    Timestamp: Timestamp
    Tags: Tags
  }
}

module logicApp_HostPool './logicApp_HostPool.bicep' = {
  name: 'LogicApp_HostPool'
  params: {
    AutomationAccountName: AutomationAccountName
    CloudEnvironment: CloudEnvironment
    Location: Location
    LogicAppName: '${LogicAppName}-HostPool'
    RunbookNameGetHostPool: RunbookNameGetHostPool
    RunbookURI: '${ScriptsRepositoryUri}${RunbookScriptGetHostPool}'
    SubscriptionId: SubscriptionId
    Timestamp: Timestamp
    Tags: Tags
  }
}



