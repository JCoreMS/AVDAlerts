param ActionGroupName string
param AutomationAccountName string
param DistributionGroup string
//param FunctionAppName string
//param HostingPlanName string
//param HostPoolResourceGroupNames array
param Location string
param LogAnalyticsWorkspaceResourceId string
param LogAlerts array
//param LogAnalyticsWorkspaceName string
param LogicAppName string
param MetricAlerts object
param RunbookName string
param RunbookScript string
@secure()
param ScriptsRepositorySasToken string
param ScriptsRepositoryUri string
param SessionHostsResourceGroupIds array
param StorageAccountResourceIds array
param Tags object
param Timestamp string = utcNow('u')
param FileServicesResourceIDs array
param ANFVolumeResourceIds array


// var Environment = environment().name
// var SubscriptionId = subscription().subscriptionId

//var LogAnalyticsRG = split(LogAnalyticsWorkspaceResourceId, '/')[4]

// Commenting out the Function App resources until Custom Metrics / Logs is supported in Azure US Government
/* resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: HostingPlanName
  location: Location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
  }
  properties: {

  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: 'storavdmetricsfuncapp'
  location: Location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: FunctionAppName
  location: Location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    siteConfig: {
      powerShellVersion: '~7'
      appSettings: [
        {
          name: 'AzureWebJobs.AVDMetrics-Every5Min.Disabled'
          value: '0'
        }
        {
          name: 'SubscriptionName'
          value: subscription().displayName
        }
        {
          name: 'subscriptionID'
          value: subscription().subscriptionId
        }
        {
          name: 'LogAnalyticsWorkSpaceName'
          value: LogAnalyticsWorkspaceName
        }
        {
          name: 'HostPoolResourceGroupNames'
          value: string(HostPoolResourceGroupNames)
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, '2019-06-01').keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, '2019-06-01').keys[0].value}'
        }
      ] 
    }
  }
  dependsOn: [
    hostingPlan
  ]
}*/

// resource function 'Microsoft.Web/sites/functions@2021-03-01' = {
//   name: 'AVDMetrics-Every5Min'
//   kind: 'functionapp'
//   parent: functionApp
//   properties: {
//     config: {
//       disabled: false
//       language: 'powershell'
//       bindings: [
//         {
//           name: 'Timer'
//           type: 'timerTrigger'
//           direction: 'in'
//           schedule: '0 */5 * * * *'
//         }
//       ]
//     }
//     files: {
//       'run.ps1': loadTextContent('run.ps1')
//       '../requirements.psd1': loadTextContent('requirements.psd1')
//     }
//   }
// }

resource actionGroup 'Microsoft.Insights/actionGroups@2019-06-01' = {
  name: ActionGroupName
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

resource metricAlerts_VirtualMachines 'Microsoft.Insights/metricAlerts@2018-03-01' = [for i in range(0, length(MetricAlerts.virtualMachines)): {
  name: MetricAlerts.virtualMachines[i].name
  location: 'global'
  tags: Tags
  properties: {
    description: MetricAlerts.virtualMachines[i].description
    severity: MetricAlerts.virtualMachines[i].severity
    enabled: false
    scopes: SessionHostsResourceGroupIds
    evaluationFrequency: MetricAlerts.virtualMachines[i].evaluationFrequency
    windowSize: MetricAlerts.virtualMachines[i].windowSize
    criteria: MetricAlerts.virtualMachines[i].criteria
    autoMitigate: false
    targetResourceType: MetricAlerts.virtualMachines[i].targetResourceType
    targetResourceRegion: Location
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
  }
}]


/* resource metricAlerts_StorageAccounts 'Microsoft.Insights/metricAlerts@2018-03-01' = [for i in range(0, length(MetricAlerts.storageAccounts)): {
  name: '${MetricAlerts.storageAccounts[i].name}-${i}'
  location: 'global'
  tags: Tags
  properties: {
    severity: MetricAlerts.storageAccounts[i].severity
    enabled: false
    scopes: StorageAccountResourceIds
    evaluationFrequency: MetricAlerts.storageAccounts[i].evaluationFrequency
    windowSize: MetricAlerts.storageAccounts[i].windowSize
    criteria: MetricAlerts.storageAccounts[i].criteria
    autoMitigate: false
    targetResourceType: MetricAlerts.storageAccounts[i].targetResourceType
    targetResourceRegion: Location
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}] */

module storAccountMetric 'storAccountMetric.bicep' = [for i in range(0, length(StorageAccountResourceIds)): {
  name: 'MetricAlert_StorageAccount_${i}'
  params: {
    Location: Location
    StorageAccountResourceID: StorageAccountResourceIds[i]
    MetricAlertsStorageAcct: MetricAlerts.storageAccounts
    ActionGroupID: actionGroup.id
    Tags: Tags
  }
}]

module azureNetAppFilesMetric 'anfMetric.bicep' = [for i in range(0, length(ANFVolumeResourceIds)): {
  name: 'MetricAlert_ANF_${i}'
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
module fileServicesMetric 'fileservicsmetric.bicep' = [for i in range(0, length(FileServicesResourceIDs)): {
  name: 'MetricAlert_FileServices_${i}'
  params: {
    Location: Location
    FileServicesResourceID: FileServicesResourceIDs[i]
    MetricAlertsFileShares: MetricAlerts.fileShares
    ActionGroupID: actionGroup.id
    Tags: Tags
  }
}]



/* resource metricAlerts_avdCustomMetrics 'Microsoft.Insights/metricAlerts@2018-03-01' = [for i in range(0, length(MetricAlerts.avdCustomMetrics)): {
  name: MetricAlerts.avdCustomMetrics[i].name
  location: 'global'
  tags: Tags
  properties: {
    severity: MetricAlerts.avdCustomMetrics[i].severity
    enabled: false
    scopes: LogAnalyticsWorkspaceResourceID
    evaluationFrequency: MetricAlerts.avdCustomMetrics[i].evaluationFrequency
    windowSize: MetricAlerts.avdCustomMetrics[i].windowSize
    criteria: MetricAlerts.avdCustomMetrics[i].criteria
    autoMitigate: false
    targetResourceType: MetricAlerts.avdCustomMetrics[i].targetResourceType
    targetResourceRegion: Location
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}] */

resource scheduledQueryRules 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = [for i in range(0, length(LogAlerts)): {
  name: LogAlerts[i].name
  location: Location
  tags: Tags
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

resource automationAccount 'Microsoft.Automation/automationAccounts@2021-06-22' = {
  name: AutomationAccountName
  location: Location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Free'
    }
  }
}

resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  parent: automationAccount
  name: RunbookName
  location: Location
  properties: {
    runbookType: 'PowerShell'
    logProgress: false
    logVerbose: false
    publishContentLink: {
      uri: '${ScriptsRepositoryUri}${RunbookScript}${ScriptsRepositorySasToken}'
      version: '1.0.0.0'
    }
  }
}

resource webhook 'Microsoft.Automation/automationAccounts/webhooks@2015-10-31' = {
  parent: automationAccount
  name: '${runbook.name}_${dateTimeAdd(Timestamp, 'PT0H', 'yyyyMMddhhmmss')}'
  properties: {
    isEnabled: true
    expiryTime: dateTimeAdd(Timestamp, 'P5Y')
    runbook: {
      name: runbook.name
    }
  }
}

resource variable 'Microsoft.Automation/automationAccounts/variables@2019-06-01' = {
  parent: automationAccount
  name: 'WebhookURI_${runbook.name}'
  properties: {
    value: '"${webhook.properties.uri}"'
    isEncrypted: false
  }
}

// Enables the runbook logs in Log Analytics for alerting and dashboards
resource diagnostics 'Microsoft.Insights/diagnosticsettings@2017-05-01-preview' = if (!empty(LogAnalyticsWorkspaceResourceId)) {
  scope: automationAccount
  name: 'diag-${automationAccount.name}'
  properties: {
    logs: [
      {
        category: 'JobLogs'
        enabled: true
      }
      {
        category: 'JobStreams'
        enabled: true
      }
    ]
    workspaceId: LogAnalyticsWorkspaceResourceId
  }
}

resource logicApp 'Microsoft.Logic/workflows@2016-06-01' = {
  name: LogicAppName
  location: Location
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      actions: {
        HTTP: {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: replace(variable.properties.value, '"', '')
            body: {
              // Examples of values to pass to the runbook
              // Environment: Environment
              // SubscriptionId: SubscriptionId
              StorageAccountResourceIDs: StorageAccountResourceIds
            }
          }
        }
      }
      triggers: {
        Recurrence: {
          type: 'Recurrence'
          recurrence: {
            frequency: 'Minute'
            interval: 5
          }
        }
      }
    }
  }
}

// output functionAppName string = functionApp.name
// output functionAppPrincipalID string = functionApp.identity.principalId
output automationAccountPrincipalId string = automationAccount.identity.principalId
