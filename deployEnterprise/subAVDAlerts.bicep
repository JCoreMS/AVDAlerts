targetScope = 'subscription'

param AutomationAccountName string
param DistributionGroup string
param Location string
param LogAnalyticsWorkspaceResourceId string
param LogAlerts array
param LogicAppName string
param MetricAlerts object
param ResourceGroupName string
// param RoleAssignments object
param RunbookNameGetStorage string
param RunbookNameGetHostPool string
param RunbookScriptGetStorage string
param RunbookScriptGetHostPool string
@secure()
param ScriptsRepositorySasToken string
param ScriptsRepositoryUri string
param SessionHostsResourceGroupIds array
param StorageAccountResourceIds array
param ActionGroupName string
param ANFVolumeResourceIds array
param Tags object


resource resourceGroupAVDMetrics 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: ResourceGroupName
  tags: Tags
  location: Location
}

module resources 'modules/resources.bicep' = {
  name: 'MonitoringResourcesDeployment'
  scope: resourceGroupAVDMetrics
  params: {
    AutomationAccountName: AutomationAccountName
    DistributionGroup: DistributionGroup
    //FunctionAppName: FunctionAppName
    //HostingPlanName: HostingPlanName
    //HostPoolResourceGroupNames: HostPoolResourceGroupNames
    Location: Location
    LogAnalyticsWorkspaceResourceId: LogAnalyticsWorkspaceResourceId
    //LogAnalyticsWorkspaceName: LogAnalyticsWorkspaceName
    LogAlerts: LogAlerts
    LogicAppName: LogicAppName
    MetricAlerts: MetricAlerts
    RunbookNameGetStorage: RunbookNameGetStorage
    RunbookNameGetHostPool: RunbookNameGetHostPool
    RunbookScriptGetStorage: RunbookScriptGetStorage
    RunbookScriptGetHostPool: RunbookScriptGetHostPool
    ScriptsRepositorySasToken: ScriptsRepositorySasToken
    ScriptsRepositoryUri: ScriptsRepositoryUri
    SessionHostsResourceGroupIds: SessionHostsResourceGroupIds
    StorageAccountResourceIds: StorageAccountResourceIds
    ActionGroupName: ActionGroupName
    ANFVolumeResourceIds: ANFVolumeResourceIds
    Tags: Tags
  }
}
output automationAccountPrincipalId string = resources.outputs.automationAccountPrincipalId
