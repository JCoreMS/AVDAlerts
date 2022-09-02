
param Location string
param Timestamp string
param StorageAccountResourceIds array

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'ds-fileServicesResourceIDs'
  location: Location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '5.4'
    cleanupPreference: 'OnSuccess'
    scriptContent: '''
      param([array]$StorAcctResIDs)
      $fileServices = @()
      foreach($storacct in $StorAcctResIDs){$fileServices += $storacct + "/fileServices/default"}
      $fileServices = $fileServices -replace '[[\]]',''
      $DeploymentScriptOutputs = @{}
      $DeploymentScriptOutputs["fileServicesResourceIDs"] = $fileServices
    '''
    arguments: ' -StorAcctResIDs ${StorageAccountResourceIds}'
    forceUpdateTag: Timestamp
    retentionInterval: 'P1D'
    timeout: 'PT30M'
  }
}
output fileServicesResourceIDs array = deploymentScript.properties.outputs.fileServicesResourceIDs
