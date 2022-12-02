// Loop for each sub due to scope property
param ActionGroup string
param CurrentSub string
param Location string
param MetricAlerts object
param VMRGResourceIds array
param Tags object
param Timestamp string

// Deployment Script for Scope for current subscription
// Loop for each sub due to scope property
resource deploymentScript_VMMetrics 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'ds-VMMetrics-${CurrentSub}'
  tags: Tags
  location: Location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '5.4'
    cleanupPreference: 'OnSuccess'
    scriptContent: '''
      param([array]$VMRGResourceIds,[string]$CurrentSub)
      $Scope =@()
      Foreach($item in $VMRGResourceIds){If($item.contains($CurrentSub)){$Scope += $item}}
      $Scope = $Scope -replace '[[]',''
      $DeploymentScriptOutputs = @{}
      $DeploymentScriptOutputs["Scope"] = $Scope
    '''
    arguments: ' -VMRGResourceIds ${VMRGResourceIds} -CurrentSub ${CurrentSub}'
    forceUpdateTag: Timestamp
    retentionInterval: 'P1D'
    timeout: 'PT30M'
  }
}



resource metricAlerts_VirtualMachines 'Microsoft.Insights/metricAlerts@2018-03-01' = [for alert in (MetricAlerts.virtualMachines): {
  name: '${alert.name}-SubID-${CurrentSub}'
  location: 'global'
  tags: Tags
  properties: {
    description: alert.description
    severity: alert.severity
    enabled: false
    scopes: deploymentScript_VMMetrics.properties.outputs.Scope
    evaluationFrequency: alert.evaluationFrequency
    windowSize: alert.windowSize
    criteria: alert.criteria
    autoMitigate: false
    targetResourceType: alert.targetResourceType
    targetResourceRegion: Location
    actions: [
      {
        actionGroupId: ActionGroup
        webHookProperties: {}
      }
    ]
  }
}]
