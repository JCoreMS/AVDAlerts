param(
    
    [parameter(Mandatory)]
    [array]$AVDResourceIDs
)


$ErrorActionPreference = 'Stop'


# Object for collecting output
$DeploymentScriptOutputs = @{}

# =================================================================================================
# AVD Host Pool RG Names
# =================================================================================================
Foreach ($itemID in $AVDResourceIDs) {
    $AVDResourceRG = ($itemID -split '/')[4]
    $SubID = ($itemID -split '/')[2]
    $HostPools = Get-AzWvdHostPool -ResourceGroupName $AVDResourceRG
    $SessionHosts = @()
    $AVDResourceIDs = @()
    $VMResIDs = @()
    $HostPoolInfo = @()

    Foreach ($HostPool in $HostPools) {
        $SessionHosts = (Get-AzWvdSessionHost -SubscriptionId $SubID -ResourceGroupName $AVDResourceRG -HostPoolName $HostPool.Name).Name
        $HostPoolResID = $HostPool.Id
        
        foreach($sessionHost in $SessionHosts){
            $sessionHost = ($sessionHost -split '/')[1]
            If ($sessionHost.Count -eq 0) { Write-Host "No Session Hosts Found in:" $HostPool.Name -ForegroundColor Yellow }
            Else {
                $DotLocation = $sessionHost.IndexOf('.')
                If ($DotLocation -ne -1) { $sessionHost = $sessionHost.Substring(0, $DotLocation) }
                $VMResID = (Get-AzVM -Name $sessionHost).Id
                If($VMResID.Count -ne 0){
                    $VMRGResID = "/"+($VMResID -split '/')[1..4] -join '/'
                    $VMResIDs += $VMResID
                }
            }            
        }
        $HostPoolInfo += @(
        [PSCustomObject]@{
            HostPoolResID = $HostPoolResID
            VMResourceGroupID = $VMRGResID
            VMResIDs = $VMResIDs
            }
        )
        $VMResIDs = @()    
    }
}
$AllVMRGs = @()
foreach($RG in $HostPoolInfo.VMResIDs){$AllVMRGs += $RG}

$DeploymentScriptOutputs["HostPoolInfo"] = $HostPoolInfo
$DeploymentScriptOutputs["AllVMRGs"] = $AllVMRGs
