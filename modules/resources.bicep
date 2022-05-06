param ActionGroupId string
param DistributionGroup string
param FunctionAppName string
param HostingPlanName string
param HostPoolResourceGroupNames array
param Location string
param LogAlerts array
param LogAnalyticsWorkspaceName string
param LogAnalyticsWorkspaceResourceId string
param MetricAlerts object
param SessionHostResourceGroupId string
param StorageAccountResourceIds array
param Tags object


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
      'run.ps1': loadTextContent('Get-AvdMetrics.ps1')
      'requirements.psd1': loadTextContent('requirements.psd1')
    }
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2019-06-01' = {
  name: 'AvdEmail'
  location: 'global'
  properties: {
    groupShortName: 'AvdEmail'
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
    enabled: false
    evaluationFrequency: LogAlerts[i].evaluationFrequency
    scopes: [
      LogAnalyticsWorkspaceResourceId
    ]
    severity: LogAlerts[i].severity
    windowSize: LogAlerts[i].windowSize
  }
}]

resource metricAlerts_VirtualMachines 'microsoft.insights/metricAlerts@2018-03-01' = [for i in range(0, length(MetricAlerts)): {
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

resource metricAlerts_StorageAccounts 'microsoft.insights/metricAlerts@2018-03-01' = [for i in range(0, length(MetricAlerts)): {
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
        actionGroupId: ActionGroupId
      }
    ]
  }
}]


output functionAppName string = functionApp.name
output functionAppPrincipalID string = functionApp.identity.principalId
