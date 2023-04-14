$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'
$templateURI = 'https://raw.githubusercontent.com/JCoreMS/AVDAlerts/main/deploySubscription/solution.json'

# VARIABLES
$filetimestamp = Get-Date -Format "MM.dd.yyyy_THH.mm" 
$OutputFile = './Parameters_' + $filetimestamp + '.json'

Write-Host "This script will help you collect the following information and build out your parameters file for deployment."
Write-Host "While mulitple storage resouces can be defined, you will only be prompted for a single option via this script" -ForegroundColor Yellow


# =================================================================================================
# Set Environment for Deployment
# =================================================================================================
Write-Host "Getting Azure Cloud list..." -ForegroundColor Yellow
$CloudList = (Get-AzEnvironment).Name
Write-Host "Which Azure Cloud would you like to deploy to?"
Foreach($cloud in $CloudList){Write-Host ($CloudList.IndexOf($cloud)+1) "-" $cloud}
$select = Read-Host "Enter selection"
$Environment = $CloudList[$select-1]
Write-Host "Connecting to Azure... (Look for minimized or hidden window)" -ForegroundColor Yellow
Connect-AzAccount -Environment $Environment | Out-Null
Clear-Host


# =================================================================================================
# Set Tenant for Deployment
# =================================================================================================
[array]$Tenants = Get-AzTenant
If ($Tenants.count -gt 1){
    Write-Host "Which Azure Tenant would you like to deploy to?"
    Foreach($Tenant in $Tenants){
        Write-Host ($Tenants.Indexof($Tenant)+1) "-" $Tenant.Name
    }
    $TenantSelection = Read-Host "Enter selection"
    $TenantId = ($Tenants[$TenantSelection-1]).Id
    Clear-Host
}
else{$TenantId = $Tenants[0].Id}

# =================================================================================================
# Set Subscription for Deployment
# =================================================================================================
Write-Host "Which Azure Subscription would you like to deploy the AVD Metrics solution in?"
[array]$Subs = Get-AzSubscription -TenantId $TenantId
Foreach($Sub in $Subs){
    Write-Host ($Subs.Indexof($Sub)+1) "-" $Sub.Name
 }
$SubSelection = Read-Host "Enter selection"
$SubID = ($Subs[$SubSelection-1]).Id
Set-AzContext -Tenant $TenantId -Subscription $SubID | Out-Null
Clear-Host


# =================================================================================================
# Get distro email address
# =================================================================================================
$DistributionGroup = Read-Host "Provide the email address of the user or distribuition list for AVD Alerts (Disabled by default)"
Clear-Host


# =================================================================================================
# Get Alert Name Prefix
# =================================================================================================
$AlertNamePrefix = Read-Host "Provide the Alert Name Prefix you would like to use. To use the default of 'AVD-' just hit ENTER."
Clear-Host


# =================================================================================================
# Get Location to be used
# =================================================================================================
Write-Host "If you need a list of Locations you can also run the following at a PowerShell prompt:"
Write-Host "Connect-AzAccount; get-AzLocation | fl Location"
$Location = Read-Host "Enter the Azure deployment location (e.g. eastus)"
Clear-Host

# =================================================================================================
# Resource Group Name to be used
# =================================================================================================
Write-Host "By default a Resource Group will be created 'rg-avdmetrics-<environment>-<region>'"
Write-Host "Would you like to define you're own Resource Group Name or use an Existing?"
$selection = Read-Host "Y, N or E (existing)"
If($selection.ToUpper() -eq 'Y'){
    Write-Host "Some examples are: rg-eastus2-avdmetrics, rg-avdalerts-eus2"
    $RGName = Read-Host "Resource Group Name"
}
If($selection.ToUpper() -eq 'E'){
    $RGList = Get-AzResourceGroup
    $i = 1
    Write-Host "Select one of your existing Resource Groups:"
    Foreach($Item in $RGList){
        Write-Host $i" -"($Item.ResourceGroupName)" ("($Item.Location)")"
        $i++
    }
    $selection = Read-Host "Resource Group"
    $RGName = $RGList[$selection-1].ResourceGroupName
}
Clear-Host


# =================================================================================================
# Environment to deploy (Prod, Dev, Test)
# =================================================================================================
Write-Host "What type of Environment Type is this being deployed to? (This is simply used in naming resources)"
Write-Host "P - Production"
Write-Host "D - Development"
Write-Host "T - Test"
$EnvType = Read-Host "Select the corresponding letter"
$EnvType = $EnvType.ToLower() 
If(($EnvType -ne "p") -and ($EnvType -ne "d") -and ($EnvType -ne "t"))
    {
        Write-Host "You must select one of the above! Exiting!" -foregroundcolor Red
        Break
    }
Clear-Host


# =================================================================================================
# AVD Host Pool RG Names
# =================================================================================================
Write-Host "Getting AVD Host Pools in Subscription..."
$AVDResourceRG = ""
$RGs = @()
$AVDHostPools = Get-AzResource -ResourceType 'Microsoft.DesktopVirtualization/hostPools'
Foreach($item in $AVDHostPools){$RGs += $AVDHostPools.ResourceGroupName}
$RGs = $RGs | Sort-Object -Unique
If ($RGs.count -gt 1){
    Write-Host "More than 1 RG found!"
    $i=1
    Foreach($RG in $RGs){
        Write-Host $i" - "$RG
        $i++
        }
    Write-Host "Select the number corresponding to the Resource Group containing your AVD HostPool Resources."
    Write-Host "The script will find the Resource Groups with the corresponding VMs!" -ForegroundColor Yellow
    #Write-Host "(For multiples type the number separated by a comma or 1,3,5 as an example)"  #### TO HANDLE MULTIPLE LATER
    $response = Read-Host "Selection:"
    $AVDResourceRG = $RGs[$response-1]
}
Else {
    Write-Host "Adding the only SINGLE Resource Group found with Host Pool resources:" $RGs
    $AVDResourceRG = $RGs
}
Write-Host "..Getting Resource Groups with associated VMs... PLEASE WAIT!" -ForegroundColor Yellow
$HostPools = Get-AzWvdHostPool -ResourceGroupName $AVDResourceRG
$SessionHosts = @()
$AVDVMRGs = @()
$AVDResourceIDs = @()
Foreach($HostPool in $HostPools){
    $CurrSessionHost = ((Get-AzWvdSessionHost -SubscriptionId $SubID -ResourceGroupName $AVDResourceRG -HostPoolName $HostPool.Name).Name -split '/')[1]
    If($null -eq $CurrSessionHost){Write-Host "No Session Hosts Found in:" $HostPool.Name -ForegroundColor Yellow}
    Else{
        $DotLocation = $CurrSessionHost.IndexOf('.')
        If($DotLocation -ne -1){$CurrSessionHost = $CurrSessionHost.Substring(0,$DotLocation)}
        $AVDVMRGs += (Get-AzVM -Name $CurrSessionHost).ResourceGroupName
        $SessionHosts += $CurrSessionHost
    }
}
$AVDVMRGs = $AVDVMRGs | Sort-Object | Get-Unique
$AVDVMRGIds = @()
Foreach ($AVDVMRG in $AVDVMRGs){
    $AVDVMRGIds += (Get-AzResourceGroup -Name $AVDVMRG).ResourceId
}

Foreach ($item in $AVDVMRGIds){
    $AVDResourceIDs += $item
}
Clear-Host


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
$LogAnalyticsWorkspace = $LogAnalyticsWorkspaces[$response-1].ResourceId
Clear-Host


# =================================================================================================
#Azure Storage Accounts
# =================================================================================================
Write-Host "Getting Azure Storage Accounts..."
$StorageAccts = $null
$StorageAcct = $null
[array]$StorageAccts = Get-AzStorageAccount
IF($StorageAccts.count -gt 0){
    $i=1
    Foreach($StorAcct in $StorageAccts){
        Write-Host $i" -"($StorAcct.StorageAccountName)
        $i++
        }
    Write-Host "Select the number corresponding to the Storage Account containing AVD related file shares"
    $response = Read-Host "For multiples seperate each number with a comma (i.e. 1,3,4)`n"
    if(!$response){
        $StorageAcct = @()
        }
    else{
        $selection = $response -split ","
        foreach($entry in $selection){$StorageAcct += @("$($StorageAccts[$entry-1].Id)")}
        }
}
ELSE {
    $StorageAcct = @()
}
Clear-Host


# =================================================================================================
#ANF Volumes
# =================================================================================================
Write-Host "Getting Azure NetApp Filer Pools\Volumes..."
$ANFVolumeResources = $null
$ANFVolumeResource = $null
     # Need RG, AccountName and Pool Name
[array]$ANFVolumeResources = Get-AzResource -ResourceType 'Microsoft.NetApp/netAppAccounts/capacityPools/volumes'
IF($ANFVolumeResources.count -eq 0){
    $ANFVolumeResource = @()
    }
ELSEIF($ANFVolumeResources.count -eq 1){
    Write-Host "Only found a single ANF Volume and capturing:`n`t" ($ANFVolumeResources.Name -split '/')[1]"\"($ANFVolumeResources.Name -split '/')[2]
    [array]$ANFVolumeResource = $ANFVolumeResources[0].ResourceId}
Else{
    $i=1
    Foreach($ANFVolRes in $ANFVolumeResources){
        $ANFVolName = ($ANFVolRes.Name -split '/')[2]
        $ANFPool = ($ANFVolRes.Name -split '/')[1]
        Write-Host $i" - "$ANFPool"\"$ANFVolName
        $i++
        }
    Write-Host "Select the number corresponding to the Azure NetApp Capacity Pool / Volume."
    $response = Read-Host "For multiples seperate each number with a comma (i.e. 1,3,4)`n"
    
    $selection = $response -split ","
    foreach($entry in $selection){[array]$ANFVolumeResource += $ANFVolumeResources[$entry-1].ResourceId}
}
Clear-Host


# =================================================================================================
# Desired Tags   
# =================================================================================================
Write-Host "Azure Tags are in a key pair format. Please input the Tag you would like to add to the resources."
Write-Host "Simply hit ENTER to contine adding mulitple tag key pairs and type X, to exit input!"
Write-Host "(i.e Name:Value or Environment:Lab)"
$Tags = @{}
$AddMore = $true
do {
    $UsrInput = Read-Host "Enter key / value pairs"
    If (($UsrInput.ToUpper() -eq "X") -or ($UsrInput -eq "")){$AddMore = $false}
    else{
        $Key = $UsrInput.Split(':')[0]
        $Value = $UsrInput.Split(':')[1]
        $Tags += @{$Key="$Value"}
    }
} while ($AddMore)


# Accomodate option for Alert Name Prefix if empty, use default
if ($AlertNamePrefix -eq ''){$AlertNamePrefix = "AVD-"}

# Output Tags in JSON format
$Parameters = [pscustomobject][ordered]@{
    '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
    contentVersion = "1.0.0.0"
    parameters = [pscustomobject][ordered]@{
        AlertNamePrefix = [pscustomobject][ordered]@{
            value = $AlertNamePrefix
        }
        DistributionGroup = [pscustomobject][ordered]@{
            value = $DistributionGroup
        }
        Environment = [pscustomobject][ordered]@{
            value = $EnvType
        }
        HostPools = [pscustomobject][ordered]@{
            value = $AVDHostPools.Name
        }
        Location =  [pscustomobject][ordered]@{
            value = $Location
        }
        UserResourceGroup = [pscustomobject][ordered]@{
            value = $RGName
        }
        LogAnalyticsWorkspaceResourceId = [pscustomobject][ordered]@{
            value = $LogAnalyticsWorkspace
        }
        SessionHostsResourceGroupIds = [pscustomobject][ordered]@{
            value = $AVDResourceIDs
        }
        StorageAccountResourceIds = [pscustomobject][ordered]@{
            value = $StorageAcct
        }
        ANFVolumeResourceIds = [pscustomobject][ordered]@{
            value = $ANFVolumeResource
        }
        Tags = [pscustomobject][ordered]@{
            value = $Tags
        }
    }
}
$JSON = $Parameters | ConvertTo-Json -Depth 5
$JSON | Out-File $OutputFile
Clear-Host

# Write Output for awareness
Write-Host "Azure Parameters information saved as... `n$OutputFile" -foregroundcolor Green

# Summary:
Clear-Host
Write-Host "Summary of Selections" -ForegroundColor Green
Write-Host "====================================================================================" -ForegroundColor Green
Write-Host "Subscription for Alerts Solution:" -ForegroundColor Cyan
Write-Host "`t$SubId"
Write-Host "AVD Alert Name Prefix:" -ForegroundColor Cyan
Write-Host "`t$AlertNamePrefix"
Write-Host "Email for Alerts:" -foregroundcolor Cyan
Write-Host "`t$DistributionGroup"
Write-Host "Environment Type:" -foregroundcolor Cyan
Write-Host "`t$EnvType"
Write-Host "Host Pools (Resource IDs):" -foregroundcolor Cyan
foreach($item in $AVDHostPools){Write-Host "`t"$item.Name}
Write-Host "Location:" -foregroundcolor Cyan
Write-Host "`t$Location"
Write-Host "Log Analytics Workspace:" -foregroundcolor Cyan
Write-Host "`t$LogAnalyticsWorkspace"
Write-Host "Resource Group Name (if custom):" -foregroundcolor Cyan
Write-Host "`t$RGName"
Write-Host "Azure Files Storage:" -foregroundcolor Cyan
foreach($item in $StorageAcct){Write-Host "`t$item"}
Write-Host "NetApp Files Volume:" -foregroundcolor Cyan
foreach($item in $ANFVolumeResource){Write-Host "`t$item"}
Write-Host "Host Pool VM Resource Groups:" -foregroundcolor Cyan
foreach($item in $AVDResourceIDs){Write-Host "`t$item"}
Write-Host "Tags for resources:" -foregroundcolor Cyan
Write-Output $Tags
Pause

# Launch Deployment
$ToDeploy = Read-Host "`nDeploy Now? (Y or N)"
If($ToDeploy.ToUpper() -eq 'Y'){
    Write-Host "Launching Deployment..."
    New-AzDeployment -Name "AVD-Alerts-Solution" -TemplateUri $templateURI -TemplateParameterFile $OutputFile -Location $Location -Verbose
}
else {
    Write-Host "Exiting..." -ForegroundColor Yellow
    Write-Host "Please use the following to deploy with your pre-created Paramaters file: $OutputFile"
    Write-Host """New-AzDeployment -Name "AVD-Alerts-Solution" -TemplateUri $templateURI -TemplateParameterFile $OutputFile -Location $Location"""
}