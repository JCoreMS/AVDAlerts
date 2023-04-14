param AutoMitigate bool
param ActionGroupId string
param Enabled bool
param HostPoolInfo object  // Should be single object from array of objects collected via Deployment Script
param MetricAlerts object
param Tags object
param Location string

resource metricAlerts_VirtualMachines 'Microsoft.Insights/metricAlerts@2018-03-01' = [for i in range(0, length(MetricAlerts.virtualMachines)): if(HostPoolInfo.VMResourceGroup != null) {
  name:  replace(MetricAlerts.virtualMachines[i].name, 'xHostPoolNamex', HostPoolInfo.HostPoolName)
  location: 'global'
  tags: contains(Tags, 'Microsoft.Insights/metricAlerts') ? Tags['Microsoft.Insights/metricAlerts'] : {}
  properties: {
    description: MetricAlerts.virtualMachines[i].description
    severity: MetricAlerts.virtualMachines[i].severity
    enabled: Enabled
    scopes: [HostPoolInfo.VMResourceGroup]  //Assuming first VM Resource ID has same RG for all
    evaluationFrequency: MetricAlerts.virtualMachines[i].evaluationFrequency
    windowSize: MetricAlerts.virtualMachines[i].windowSize
    criteria: MetricAlerts.virtualMachines[i].criteria
    autoMitigate: AutoMitigate
    targetResourceType: MetricAlerts.virtualMachines[i].targetResourceType
    targetResourceRegion: Location
    actions: [
      {
        actionGroupId: ActionGroupId
        webHookProperties: {}
      }
    ]
  }
}]


output HostPoolInfo object = HostPoolInfo
output HostPoolName string = HostPoolInfo.HostPoolName
output HostPoolRG string = HostPoolInfo.VMResourceIDs != null ? split(HostPoolInfo.VMResourceIDs[0], '/')[4] : 'Null Value'
