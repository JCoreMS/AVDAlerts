    
    [Cmdletbinding()]
    Param(
        [parameter(Mandatory)]
        [string]
        $HostPoolRegistrationToken,
        [parameter(Mandatory)]
        [string]
        $XTenantRegister,
        [parameter(Mandatory)]
        [string]
        $XTenantRegToken
    )
    
##############################################################
#  Install the AVD Agent
##############################################################
# Determine cross Tenant registration 
If($XTenantRegister){$HostPoolRegistrationToken = $XTenantRegToken}

# Disabling this method for installing the AVD agent until AAD Join can completed successfully
$BootInstaller = 'AVD-Bootloader.msi'
Get-WebFile -FileName $BootInstaller -URL 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH'
Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i $BootInstaller /quiet /qn /norestart /passive" -Wait -Passthru
Write-Log -Message 'Installed AVD Bootloader' -Type 'INFO'
Start-Sleep -Seconds 5

$AgentInstaller = 'AVD-Agent.msi'
Get-WebFile -FileName $AgentInstaller -URL 'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv'
Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i $AgentInstaller /quiet /qn /norestart /passive REGISTRATIONTOKEN=$HostPoolRegistrationToken" -Wait -PassThru
Write-Log -Message 'Installed AVD Agent' -Type 'INFO'
Start-Sleep -Seconds 5