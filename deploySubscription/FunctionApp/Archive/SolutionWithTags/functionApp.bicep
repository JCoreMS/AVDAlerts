param Location string
param TagName string
param TagValue string

var hostingPlanName_var = 'asp-${Location}-AVDMetricsFuncApp'
var FunctionAppName = 'fa-AVDMetrics-${Location}-autodeploy'

resource hostingPlanName 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: hostingPlanName_var
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

resource sites_FunctionAppName 'Microsoft.Web/sites@2021-03-01' = {
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
          name: 'TagName'
          value: TagName
        }
        {
          name: 'TagValue'
          value: TagValue
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
    hostingPlanName
  ]
}

resource sites_FunctionAppName_AVDMetrics_Every5Min 'Microsoft.Web/sites/functions@2021-03-01' = {
  name: 'AVDMetrics-Every5Min'
  kind: 'functionapp'
  parent: sites_FunctionAppName
 
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
      'run.ps1': loadTextContent('GetAVDMetrics.ps1')
    }
  }
}
