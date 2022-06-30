

param([array]$StorAcctResIDs)
$fileServices = @()
foreach($storacct in $StorAcctResIDs){
    #trim off leading and trailing square brackets
    $fileServices += $storacct + "/fileServices/default"}


$fileServices = '["[/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-AVDLab-Resources/providers/Microsoft.Storage/storageAccounts/storavdlabeus2/fileServices/default","/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-AVDLab-Resources/providers/Microsoft.Storage/storageAccounts/storavdlabeus3/fileServices/default"]'
$fileServices -replace '[[\]]',''

#$DeploymentScriptOutputs = @{}
#$DeploymentScriptOutputs["fileServicesResourceIDs"] = $fileServices

# ["/subscriptions/8a0ecebc-0e1d-4e8f-8cb8-8a92f49455b9/resourceGroups/rg-eastus2-AVDLab-Resources/providers/Microsoft.Storage/storageAccounts/storavdlabeus2/fileServices/default"]