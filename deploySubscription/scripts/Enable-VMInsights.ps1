##  TESTING NOT USED
# - possible deployment script to configure Insights on each VM
$Location = "eastus2"
$LogAnalyticsWorkspaceResourceId = "/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourcegroups/rg-eastus2-avdlab-manage/providers/microsoft.operationalinsights/workspaces/law-eastus2-avdlab"
$HostPoolVMResIDs = @("/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-AVDLab-Resources",
"/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-AVDLabVMs-GeneralUsers",
"/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-AVDLabVMs-HybridJoin",
"/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-AVDLabVMs-SSO",
"/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-AVDPersonalVMs")

# https://www.powershellgallery.com/packages/Install-VMInsights/1.9/Content/Install-VMInsights.ps1
# https://docs.microsoft.com/en-us/azure/azure-monitor/vm/vminsights-enable-powershell

$WorkspaceID = $LogAnalyticsWorkspaceResourceId
$WorksapceKey = Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $WorkspaceID.Split('/')[4] -Name $WorkspaceID.Split('/')[8]
$SubID = $LogAnalyticsWorkspaceResourceId.Split('/')[2]




# Install for all VM's in a Resource Group in a subscription
Install-VMExtension `
-VMName $vmName `
-VMLocation $vmLocation `
-VMResourceGroupName $vmResourceGroupName `
-ExtensionType $mmaExt `
-ExtensionName $mmaExtensionName `
-ExtensionPublisher $MMAExtensionPublisher `
-ExtensionVersion $mmaExtVersion `
-PublicSettings $PublicSettings `
-ProtectedSettings $ProtectedSettings `
-ReInstall $ReInstall `
-OnboardingStatus $OnboardingStatus


# Using PowerShell Gallery Script
Invoke-WebRequest -Uri https://www.powershellgallery.com/api/v2/package/Install-VMInsights/1.9 -OutFile ".\Install-VMInsights.zip"
Expand-Archive -LiteralPath .\Install-VMInsights.zip -DestinationPath .\vminsights
Enable-AzureRmAlias
.\vminsights\Install-VMInsights.ps1 -WorkspaceRegion eastus -WorkspaceId $WorkspaceID -WorkspaceKey $WorksapceKey.PrimarySharedKey -SubscriptionId $SubID -ResourceGroup 'rg-eastus2-AVDLabVMs-GeneralUsers' -ReInstall -Approve


