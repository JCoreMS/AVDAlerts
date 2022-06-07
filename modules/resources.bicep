param DistributionGroup string
param FunctionAppName string
param HostingPlanName string
param HostPoolResourceGroupNames array
param Location string
param MetricAlerts object
param LogAnalyticsWorkspaceResourceID string
param LogAlerts array
param LogAnalyticsWorkspaceName string
param SessionHostResourceGroupId string
param StorageAccountResourceIds array
param ActionGroupName string
param Tags object

var LogAnalyticsRG = split(LogAnalyticsWorkspaceResourceID, '/')[4]

resource hostingPlan 'Microsoft.Web/serverfarms@2021-03-01' = {
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
}

resource function 'Microsoft.Web/sites/functions@2021-03-01' = {
  name: 'AVDMetrics-Every5Min'
  kind: 'functionapp'
  parent: functionApp
  properties: {
    config: {
      disabled: false
      language: 'powershell'
      bindings: [
        {
          name: 'Timer'
          type: 'timerTrigger'
          direction: 'in'
          schedule: '0 */5 * * * *'
        }
      ]
    }
    files: {
      'run.ps1': loadTextContent('run.ps1')
      '../requirements.psd1': loadTextContent('requirements.psd1')
    }
  }
}

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
    severity: MetricAlerts.virtualMachines[i].severity
    enabled: false
    scopes: [
      SessionHostResourceGroupId
    ]
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

// If Metric Namespace contains file services ; change scopes to append default
resource metricAlerts_StorageAccounts 'Microsoft.Insights/metricAlerts@2018-03-01' = [for i in range(0, length(MetricAlerts.storageAccounts)): {
  name: MetricAlerts.storageAccounts[i].name
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

module LAWresource 'LAWresource.bicep' = {
  name: 'UpdateLogAnalyticsWorkspace'
  scope: resourceGroup(LogAnalyticsRG)
  params: {
    LogAnalyticsWorkspaceResourceID: LogAnalyticsWorkspaceResourceID
    LogAlerts: LogAlerts
    Location: Location
    ActionGroupID: actionGroup.id
    Tags: Tags
  }
}

output functionAppName string = functionApp.name
output functionAppPrincipalID string = functionApp.identity.principalId

