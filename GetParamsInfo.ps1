# VARIABLES
$TemplateParametersFile = './Parameters.json'

# Get data from parameters file
$Json = Get-Content -Path $TemplateParametersFile
$Parameters = ($Json | ConvertFrom-Json).parameters

# Update parameters file to include security group names and ID's
Function UpdateParamsFile ($item,$value){
    $Parameters | Add-Member -MemberType NoteProperty -Name $Item -Value @{'value' = $Value} -Force
    $File = $Json | ConvertFrom-Json
    $File.parameters = $Parameters
    $File | ConvertTo-Json -Depth 20 | Out-File -FilePath $TemplateParametersFile -Force
}


# Connect To Azure
Write-Host "Connect to Azure Soveriegn Cloud? (US Gov or China)"
$response = Read-Host "Y or N"
$response.ToUpper()
If($response -eq 'Y'){ 
    Write-Host "1 - US Government"
    Write-Host "2 - China"
    $response = Read-Host "Select 1 or 2 (Any other response will assume Azure Global Cloud Environment)"
    If($response -eq 1){$Environment = "AzureUSGovernment"}
    If($response -eq 2){$Environment = "AzureChina"}
}
else{$Environment = "AzureCloud"}

Connect-AzAccount -Environment $Environment

$Subs = Get-AzSubscription
Foreach($Sub in $Subs){
    Write-Host ($Subs.Indexof($Sub)+1) "-" $Sub.Name
 }

$Selection = Read-Host "Subscription"
$Selection = $Subs[$Selection-1]
Select-AzSubscription -SubscriptionObject $Selection

UpdateParamsFile 'Environment' $Environment



# =================================================================================================
CLS
# Get distro email address
# =================================================================================================
$DistributionGroup = Read-Host "Provide the email address of the user or distribuition list for AVD Alerts (Disabled by default)"
UpdateParamsFile 'DistributionGroup' $DistributionGroup


# =================================================================================================
# AVD Host Pool RG Names
# =================================================================================================
Write-Host "Getting AVD Host Pools in Subscription..."
$AVDHostPools = Get-AzResource -ResourceType 'Microsoft.DesktopVirtualization/hostPools'
Foreach($item in $AVDHostPools){$RGs += $AVDHostPools.ResourceGroupName}
$RGs = $RGs | Sort-Object -Unique
$i=1
Foreach($RG in $RGs){
    Write-Host $i" -"$RG
    $i++
    }
$response = Read-Host "Select the number corresponding to the Resource Group containing your AVD HostPool Resources"

UpdateParamsFile 'HostPoolResourceGroupNames' $AVDHostPools[$response-1].ResourceId

# =================================================================================================
#Log Analytics
# =================================================================================================
Write-Host "Getting Log Analytics Workspaces in Subscription..."
$LogAnalyticsWorkspaces = Get-AzOperationalInsightsWorkspace
$i=1
Foreach($LAW in $LogAnalyticsWorkspaces){
    Write-Host $i" -"($LAW.Name)
    $i++
    }
$response = Read-Host "Select the number corresponding to the Log Analytics Workspace containing AVD Metrics"
$LogAnalyticsWorkspace = $LogAnalyticsWorkspaces[$response-1]
UpdateParamsFile 'LogAnalyticsWorkspaceResourceID' $LogAnalyticsWorkspace.ResourceId

# =================================================================================================
#Azure Storage Accounts
# =================================================================================================
Write-Host "Getting Azure Storage Accounts..."
$StorageAccts = Get-AzStorageAccount
$i=1
Foreach($StorAcct in $StorageAccts){
    Write-Host $i" -"($StorAcct.StorageAccountName)
    $i++
    }
$response = Read-Host "Select the number corresponding to the Storage Account containing AVD related file shares"
$StorageAcct = $StorageAccts[$response-1]
UpdateParamsFile 'StorageAccountResourceIds' $StorageAcct.Id

# =================================================================================================
#ANF Volumes
# =================================================================================================
Write-Host "Getting Azure NetApp Filer Pools\Volumes..."
     # Need RG, AccountName and Pool Name
$ANFVolumeResources = Get-AzResource -ResourceType 'Microsoft.NetApp/netAppAccounts/capacityPools/volumes'
$i=1
Foreach($ANFVolRes in $ANFVolumeResources){
    $ANFVolName = ($ANFVolRes.Name -split '/')[2]
    $ANFPool = ($ANFVolRes.Name -split '/')[1]
    Write-Host $i" - "$ANFPool"\"$ANFVolName
    $i++
    }
Write-Host "(** If you need multiple please select only 1 and review/ edit the paramters file **)" -foregroundcolor Yellow
$response = Read-Host "Select the number corresponding to the ANF Volume containing AVD related file shares"

$ANFVolumeResource = $ANFVolumeResources[$response-1]
UpdateParamsFile 'ANFPoolResourceIds' $ANFVolumeResource.Id


# Write Output for awareness

Write-Host "Parameters ResouceIDs needed:`n"
Write-Host "LogAnalytics: " $LogAnalyticsWorkspace.ResourceId
Write-Host "StorageAccount: "$StorageAcct.Id
Write-Host "ANF Volume: "$ANFVolumeResource.Id







