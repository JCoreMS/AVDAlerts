param Location string
param Timestamp string
param StorageAccountResourceIds array

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2019-10-01-preview' = {
  name: 'ds-fileServicesResourceIDs'
  location: Location
  kind: 'AzurePowerShell'
  tags: {}
  identity: {}
  properties: {
    azPowerShellVersion: '5.4'
    cleanupPreference: 'OnSuccess'
    scriptContent: 'param([array]$StorAcctResIDs); $fileServices = @(); foreach($storacct in $StorAcctResIDs){$fileServices += $storacct + "/fileServices/default"}; $DeploymentScriptOutputs = @{}; $DeploymentScriptOutputs["fileServicesResourceIDs"] = $fileServices'
    arguments: ' -StorAcctResIDs ${StorageAccountResourceIds}'
    forceUpdateTag: Timestamp
    retentionInterval: 'P1D'
    timeout: 'PT30M'
  }
}

output fileServicesResourceIDs array = deploymentScript.properties.outputs.fileServicesResourceIDs
