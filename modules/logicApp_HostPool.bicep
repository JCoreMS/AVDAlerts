param AutomationAccountName string
param CloudEnvironment string
param Location string
param LogicAppName string
param RunbookNameGetHostPool string
param RunbookURI string
param SubscriptionId string
param Timestamp string
param Tags object

resource automationAccount 'Microsoft.Automation/automationAccounts@2021-06-22' existing = {
  name: AutomationAccountName
}

resource runbookGetHostPoolInfo 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  name: RunbookNameGetHostPool
  tags: contains(Tags, 'Microsoft.Automation/automationAccounts/runbooks') ? Tags['Microsoft.Automation/automationAccounts/runbooks'] : {}
  parent: automationAccount
  location: Location
  properties: {
    runbookType: 'PowerShell'
    logProgress: false
    logVerbose: false
    publishContentLink: {
      uri: RunbookURI
      version: '1.0.0.0'
    }
  }
}

resource webhookGetHostPoolInfo 'Microsoft.Automation/automationAccounts/webhooks@2015-10-31' = {
  name: '${runbookGetHostPoolInfo.name}_${dateTimeAdd(Timestamp, 'PT0H', 'yyyyMMddhhmmss')}'
  parent: automationAccount
  properties: {
    isEnabled: true
    expiryTime: dateTimeAdd(Timestamp, 'P5Y')
    runbook: {
      name: runbookGetHostPoolInfo.name
    }
  }
}

resource variableGetHostPoolInfo 'Microsoft.Automation/automationAccounts/variables@2019-06-01' = {
  name: 'WebhookURI_${runbookGetHostPoolInfo.name}'
  parent: automationAccount
  properties: {
    value: '"${webhookGetHostPoolInfo.properties.uri}"'
    isEncrypted: false
  }
}

resource logicAppGetHostPoolInfo 'Microsoft.Logic/workflows@2016-06-01' = {
  name: LogicAppName
  tags: contains(Tags, 'Microsoft.Logic/workflows') ? Tags['Microsoft.Logic/workflows'] : {}
  dependsOn: [
    automationAccount
    runbookGetHostPoolInfo
    webhookGetHostPoolInfo
  ]
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
            uri: replace(variableGetHostPoolInfo.properties.value, '"', '')
            body: {
              CloudEnvironment: CloudEnvironment
              SubscriptionId: SubscriptionId
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
