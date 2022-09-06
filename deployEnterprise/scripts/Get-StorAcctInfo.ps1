# Deployed from resources.bicep 
# Code for Runbook associated with Action Account deployment
# Collects Azure Files Storage data and writes output in following format:
# AzFiles, Subscription ,RG ,StorAcct ,Share ,Quota ,GB Used ,%Available

<#
//Kusto Query for Log Analtyics
AzureDiagnostics 
| where Category has "JobStreams"
| where StreamType_s has "Output"
| extend Results=split(ResultDescription,',')
#>

[CmdletBinding(SupportsShouldProcess)]
param(
	[Parameter(Mandatory)]
	$WebHookData
)

$Parameters = ConvertFrom-Json -InputObject $WebHookData.RequestBody

<# $Environment = $Parameters.PSObject.Properties['Environment'].Value
$FileShareName = $Parameters.PSObject.Properties['FileShareName'].Value
$ResourceGroupName = $Parameters.PSObject.Properties['ResourceGroupName'].Value
$StorageAccountName = $Parameters.PSObject.Properties['StorageAccountName'].Value
#>
$SubscriptionId = $Parameters.PSObject.Properties['SubscriptionId'].Value
$CloudEnvironment = $Parameters.PSObject.Properties['CloudEnvironment'].Value
$StorageAccts = $Parameters.PSObject.Properties['StorageAccountResourceIds'].Value

Connect-AzAccount -Identity -Environment $CloudEnvironment -SubscriptionId $SubscriptionId | Out-Null
$Output = $null

# Foreach storage account
Foreach ($storageAcct in $storageAccts) {
	$SubName = (Get-azSubscription -SubscriptionId ($storageAcct -split '/')[2]).Name
	Set-AzContext -SubscriptionId ($storageAcct -split '/')[2] | Out-Null
	$resourceGroup = ($storageAcct -split '/')[4]
	$storageAcctName = ($storageAcct -split '/')[8]
	Write-Host "Working on Storage:" $storageAcctName "in" $resourceGroup
	# $accountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroup -Name $storageAcctName)[0].Value
	# $ctx = New-AzStorageContext -StorageAccountName $storageAcctName -StorageAccountKey $accountKey
	$ctx = (Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAcctName).Context
	$shares = Get-AzStorageShare -Context $ctx
	
	# Foreach Share
	Foreach ($share in $shares) {
		$shareName = $share.Name
		#Write-Host "Share: " $shareName
		$shareInfo = Get-AzStorageShare -Name $shareName -Context $ctx
		$shareQuota = $shareInfo.Quota #GB
		$client = $shareInfo.ShareClient
		# We now have access to Azure Storage SDK and we can call any method available in the SDK.
		# Get statistics of the share
		$stats = $client.GetStatistics()
		$shareUsageInGB = $stats.Value.ShareUsageInBytes / 1073741824 # Bytes to GB
		
		$RemainingPercent = 100 - ($shareUsageInGB / $shareQuota)
		#Write-Host "..." $shareUsageInGB "of" $shareQuota "GB used"
		#Write-Host "..." $RemainingPercent "% Available"
		
		# Compile results 
		# AzFiles / Subscription / RG / StorAcct / Share / Quota / GB Used / %Available
		$Data = @('AzFiles', $SubName, $resourceGroup, $storageAcctName, $shareName, $shareQuota.ToString(), $shareUsageInGB.ToString(), $RemainingPercent.ToString())
		$i = 0
		ForEach ($Item in $Data) {
			If ($i -ne $Data.Length - 1) {
				# Ensure we don't add the trailing comma if last item
				$Output += $Item + ','
				$i += 1
			}
			else { $Output += $Item }
		}

		Write-Output $Output
		$Data = $null
		$Output = $null
	} # end for each share

} # end for each storage acct

