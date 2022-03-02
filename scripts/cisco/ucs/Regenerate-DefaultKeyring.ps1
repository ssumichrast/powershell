#Requires -Modules Cisco.UCSManager

<#
    .SYNOPSIS
    Regenerates the default UCS Keyring certificate.

    .DESCRIPTION
    Regenerates the default UCS Keyring certificate.

    .PARAMETER UCS
    FQDN of the UCS Manager domain to regenerate the default keyring certificate on

    .EXAMPLE
    .\Regenerate-DefaultKeyring.ps1 -ucs ucsmanager.mydomain.lcl

    .NOTES
    Author:     Steve sumichrast (steven.sumichrast@gmail.com)
    Version:    1.0
    Changes:    Initial Version
#>
[cmdletbinding()]
param(
    # FQDN of the UCS Domain to regenerate the default keyring certificate on
    [Parameter(Mandatory = $true)]
    [string]
    $UCS
)

# try to connect to the UCS

try {
    Write-Verbose "Attempting to connect to the UCS Domain $($UCS)"
    $UCSObj = Connect-Ucs -Name $UCS
    Write-Host "Connected to $($UCSObj.Ucs)."
}
catch {
    Write-Error "Failed to connect to UCS Manager"
    exit
}

# Find the keyring and regenerate it
try {
    Write-Verbose "Attempting to trigger a regenerate task"
    Get-UcsKeyRing -Name default -Ucs $UCSObj | Set-UcsKeyRing -Regen true -force | Out-Null
    Write-Host "$($UCSObj.Ucs): Default Keyring Certificate regeneration successful"
}
catch {
    Write-Error "Failed to trigger a certificate regeneration."
}

# Disconnect from UCS Manager
Disconnect-Ucs -Ucs $UCSObj | Out-Null