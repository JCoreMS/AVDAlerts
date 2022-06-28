

param([array]$StorAcctResIDs)
$fileServices = @()
foreach($storacct in $StorAcctResIDs)
    {$fileServices += $storacct + "/fileServices/default"}
$DeploymentScriptOutputs = @{}
$DeploymentScriptOutputs["fileServicesResourceIDs"] = $fileServices