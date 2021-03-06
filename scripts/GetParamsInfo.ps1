# VARIABLES
$filetimestamp = Get-Date -Format "MM.dd.yyyy_THH.mm" 
$OutputFile = './Parameters_' + $filetimestamp + '.json'

Write-Host "This script will help you collect the following information and build out your parameters file for deployment."
Write-Host "While mulitple storage resouces can be defined, you will only be prompted for a single option via this script" -ForegroundColor Yellow

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
Write-Host "Getting subscriptions..."
$Subs = Get-AzSubscription
Foreach($Sub in $Subs){
    Write-Host ($Subs.Indexof($Sub)+1) "-" $Sub.Name
 }

$Selection = Read-Host "Select Subscription number desired"
$Sub = $Subs[$Selection-1]
Select-AzSubscription -SubscriptionObject $Sub


# =================================================================================================
CLS
# Get distro email address
# =================================================================================================
$DistributionGroup = Read-Host "Provide the email address of the user or distribuition list for AVD Alerts (Disabled by default)"

# =================================================================================================
# Get Location to be used
# =================================================================================================
Write-Host "If you need a list of Locations you can also run the following at a PowerShell prompt:"
Write-Host "Connect-AzAccount; get-AzLocation | fl Location"
$Location = Read-Host "Type the Location for the resources to be deployed to."

# =================================================================================================
# Environment to deploy (Prod, Dev, Test)
# =================================================================================================
Write-Host "What type of Environment Type is this being deployed to?"
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
# =================================================================================================
# AVD Host Pool RG Names
# =================================================================================================
Write-Host "Getting AVD Host Pools in Subscription..."
$AVDResourceRG = ""
$RGs = ""
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
    Write-Host "  The script will find the Resource Groups with the corresponding VMs!" -ForegroundColor Yellow
    #Write-Host "(For multiples type the number separated by a comma or 1,3,5 as an example)"  #### TO HANDLE MULTIPLE LATER
    $response = Read-Host
    $AVDResourceRG = $RGs[$response-1]
}
Else {
    Write-Host "Adding the only SINGLE Resource Group found with Host Pool resources:" $RGs[0].Name
    $AVDResourceRG = $RGs
}
Write-Host "..Getting Resource Groups with associated VMs... PLEASE WAIT!" -ForegroundColor Yellow
$HostPools = Get-AzWvdHostPool -ResourceGroupName $AVDResourceRG
$SessionHosts = @()
$AVDVMRGs = @()
$AVDResourceIDs = @()
Foreach($HostPool in $HostPools){
    $CurrSessionHost = ((Get-AzWvdSessionHost -SubscriptionId $Sub.Id -ResourceGroupName $AVDResourceRG -HostPoolName $HostPool.Name).Name -split '/')[1]
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
    If($AVDVMRGIds.count -ne 1){$AVDResourceIDs += """$item""," + "`n`t`t`t"}
    Else{$AVDResourceIDs += """$item"""}
}


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
$StorageAcct = $StorageAccts[$response-1].Id


# =================================================================================================
#ANF Volumes
# =================================================================================================
Write-Host "Getting Azure NetApp Filer Pools\Volumes..."
     # Need RG, AccountName and Pool Name
$ANFVolumeResources = Get-AzResource -ResourceType 'Microsoft.NetApp/netAppAccounts/capacityPools/volumes'
IF($ANFVolumeResources.count -eq 1){
    Write-Host "Only found a single ANF Volume and capturing:`n`t" ($ANFVolumeResources.Name -split '/')[1]"\"($ANFVolumeResources.Name -split '/')[2]
    $ANFVolumeResource = $ANFVolumeResources[0].ResourceId}
Else{
    $i=1
    Foreach($ANFVolRes in $ANFVolumeResources){
        $ANFVolName = ($ANFVolRes.Name -split '/')[2]
        $ANFPool = ($ANFVolRes.Name -split '/')[1]
        Write-Host $i" - "$ANFPool"\"$ANFVolName
        $i++
        }
    Write-Host "(** If you need multiple please select only 1 and review/ edit the paramters file **)" -foregroundcolor Yellow
    $response = Read-Host "Select the number corresponding to the ANF Volume containing AVD related file shares"

    $ANFVolumeResource = $ANFVolumeResources[$response-1].ResourceId
}

# =================================================================================================
# Desired Tags   -------- Works but adds extra double quotes before and after { } for list of values
# =================================================================================================
Write-Host "Azure Tags are in a key pair format. Please input the Tag you would like to add to the resources."
Write-Host "Simply hit ENTER to contine adding mulitple tag key pairs and type X, to exit input!"
Write-Host "(i.e Name:Value or Environment:Lab)"
$Tags = @()
$AddMore = $true
do {
    $UsrInput = Read-Host "Key:Value"
    If ($UsrInput.ToUpper() -eq "X"){$AddMore = $false}
    else{$Tags += $UsrInput}
} while ($AddMore)
If($null -ne $Tags){
    #Reformat for syntax in params file
    $String = '{' + "`n`t`t`t"
    $i = 1
    Foreach($Tag in $Tags){
        $TagUpdate = $Tag -replace ':', '":"'
        Foreach ($element in $TagUpdate){
            If($Tags.count -ne $i){$String += """" + $element + """," + "`n`t`t`t"}
            Else{$String += """" + $element + """" + "`n`t`t`t"}
            $i++
        }
    }
    $String += '}'
}
# Output Tags in JSON format

$OutputHeader = @'
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
'@

$OutputBody = @"

        "DistributionGroup": {
            "value": "$DistributionGroup"
        },
        "Environment": {
            "value": "$EnvType"
        },
        "Location": {
            "value": "$Location"
        },
        "LogAnalyticsWorkspaceResourceId": {
            "value": "$LogAnalyticsWorkspace"
        },
        "ScriptsRepositorySasToken": {
            "value": ""
        },
        "ScriptsRepositoryUri": {
            "value": "https://raw.githubusercontent.com/JCoreMS/AVDAlerts/main/scripts/"
        },
        "SessionHostsResourceGroupIds": {
            "value": [
                $AVDResourceIDs
            ]
        },
        "StorageAccountResourceIds": {
            "value": [
                "$StorageAcct"
            ]
        },
        "ANFVolumeResourceIds": {
            "value": [
                "$ANFVolumeResource"
            ]
        },
        "Tags": {
            "value": $String
        }
    }
}

"@

$OutputHeader + $OutputBody | Out-File $OutputFile

# Write Output for awareness
Write-Host "Azure Parameters information saved as... `n$OutputFile" -foregroundcolor Green










