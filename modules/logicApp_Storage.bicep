param AutomationAccountName string
param CloudEnvironment string
param Location string
param LogicAppName string
param RunbookNameGetStorage string
param RunbookURI string
param StorageAccountResourceIds array
param Timestamp string
param Tags object

resource automationAccount 'Microsoft.Automation/automationAccounts@2021-06-22' existing = {
  name: AutomationAccountName
}


resource runbookGetStorageInfo 'Microsoft.Automation/automationAccounts/runbooks@2018-06-30' = {
  name: RunbookNameGetStorage
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

resource webhookGetStorageInfo 'Microsoft.Automation/automationAccounts/webhooks@2015-10-31' = {
  name: '${runbookGetStorageInfo.name}_${dateTimeAdd(Timestamp, 'PT0H', 'yyyyMMddhhmmss')}'
  parent: automationAccount
  properties: {
    isEnabled: true
    expiryTime: dateTimeAdd(Timestamp, 'P5Y')
    runbook: {
      name: runbookGetStorageInfo.name
    }
  }
}

resource logicAppGetStorageInfo 'Microsoft.Logic/workflows@2016-06-01' = {
  name: LogicAppName
  tags: contains(Tags, 'Microsoft.Logic/workflows') ? Tags['Microsoft.Logic/workflows'] : {}
  dependsOn: [
    automationAccount
    runbookGetStorageInfo
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
            uri: webhookGetStorageInfo.properties.uri
            body: {
              CloudEnvironment: CloudEnvironment
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
output RunbookURI string = RunbookURI
output webhookname string = webhookGetStorageInfo.name
output RunbookProp object = runbookGetStorageInfo.properties
