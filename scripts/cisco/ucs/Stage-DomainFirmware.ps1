<#
    .SYNOPSIS
    Downloads the A, B and C firmware packages to a UCS domain from a FTP
    Server.

    .DESCRIPTION
    This script will accept the destination version number for a UCS system and
    create a download task for the A, B and C firmware. Script assumes that
    firmware is stored in the appropriate FTP destination and uses the
    Cisco-defined naming conventions.

    .PARAMETER UCS
    One or more UCS Manager FQDNs to connect to and stage firmware on.

    .PARAMETER Version
    The Cisco version number for the release. Format used is the version number
    in filenames, not standard Cisco UCS version number format. e.g.: 4.1.3b,
    not 4.1(3b).

    .PARAMETER Infra
    Set to True (default) to download the Infrastructure bundle or False to
    skip.

    .PARAMETER BSeries
    Set to True (default) to download the B-series firmware bundle or False to
    skip.

    .PARAMETER CSeries
    Set to True (default) to download the C-Series firmware bundle or False to
    skip.

    .PARAMETER Protocol
    Transfer protocol to use.

    .PARAMETER Server
    Remote host to download the firmware from.

    .PARAMETER User
    Username to log in to the remote server with.

    .PARAMETER Password
    Password to log in to the remote server with.

    .PARAMETER RemotePath
    Any path required to access the firmware. Do not include the prefix forward
    slash or trailing slash.

    .PARAMETER Force
    Set to True to bypass the version check for the Infrastructure bundle.

    .EXAMPLE
    PS> .\Stage-DomainFirmware.ps1 -UCS ucsm01.mydomain.lcl,ucsm02.mydomain.lcl -Version 4.1.3b 

    Attempt to start a download task for firmware 4.1.3b packages from the
    default FTP location If the domain is running version 4.1.3b the script will
    terminate and inform the user the domain is already at 4.1.3b.

    .EXAMPLE
    PS> .\Stage-DomainFirmware.ps1 -UCS ucsm.mydomain.lcl -Version 4.1.3b -force

    Attempt to start a download task for firmware 4.1.3b packages from the
    default FTP location. Since the -Force parameter is present the script will
    force sending download tasks, as long as they don't already exist.

    .EXAMPLE
    PS> .\Stage-DomainFirmware.ps1 -UCS ucsm.mydomain.lcl -Version 4.1.3b -Infra:$false

    Attempt to start a download task for firmware version 4.1.3b, excluding the
    Infrastructure package. Script will also ignore current fabric version and
    just attempt to download the requested firmware package.
#>

#Requires -Modules @{ ModuleName="Cisco.UCSManager"; ModuleVersion="3.0.1.2"} -Version 7

param(
    [parameter(Mandatory = $true)]
    [string[]]$UCS,
    [parameter(Mandatory = $true)]
    [string][ValidatePattern("^[0-9].[0-9].[0-9][a-zA-Z]$")]$Version,
    [string]$Remotepath = "ucs/firmware",
    [parameter()]
    [ValidateSet("ftp", "local", "scp", "sftp", "tftp", "usbA", "usbB")]
    [string]$Protocol = "ftp",
    [parameter(Mandatory = $true)]
    [string]$Server,
    [parameter(Mandatory = $true)]
    [string]$User,
    [string]$Password,
    [bool]$Infra = $true,
    [bool]$BSeries = $true,
    [bool]$CSeries = $true,
    [bool]$force = $false
)

# Check if we're already connected to a UCS Domain and have the
# MultipleDefaultUcs set to False
if ($DefaultUcs -and (Get-UcsPowerToolConfiguration).SupportMultipleDefaultUCS -eq $false) {
    Throw "You are connected to an existing UCS domain and do not have SupportMultipleDefaultUCS Enabled."
}

# Build the firmware package versions
$FirmwareFilenames = [PSCustomObject]@{
    Infrastructure = @{
        6300 = "ucs-6300-k9-bundle-infra.$Version.A.bin"
        6324 = "ucs-mini-9-bundle-infra.$Version.A.bin"
        6400 = "ucs-6400-k9-bundle-infra.$Version.A.bin"
    }

    BSeries        = "ucs-k9-bundle-b-series.$Version.B.bin"
    CSeries        = "ucs-k9-bundle-c-series.$Version.C.bin"
}

function NewDownload($Filename) {
    Write-Verbose "NewDownload: Submitting new UcsFirmwareDownloader task to $($UCSObj.UCS); file: $Filename"
    # Check if a download task already exists
    if (Get-UCSFirmwareDownloader -Filename $Filename -Ucs $UCSObj) {
        Write-Verbose "NewDownload: Get-UCSFirmwareDownloader found an existing task to download this firmware."
        return $false
    }
    else {
        Add-UcsFirmwareDownloader -FileName $Filename -Protocol $Protocol -RemotePath $Remotepath -User $User -Pwd $Password -Server $Server -Ucs $UCSObj
        return $true
    }
}

$UCS | ForEach-Object -Begin {
    # Obtain UCS Credentials
    Write-Verbose "Collecting UCS login credentials"
    $UCSCredentials = Get-Credential -Message "Login to UCS"
    if (!$UCSCredentials) {
        Write-Error "Credentials not supplied."
    }
} -Process {
    try {
        # Connect to UCS
        $UCSObj = Connect-Ucs -Name $_ -Credential $UCSCredentials
        Write-Output "Connected to UCS Domain $($UCSObj.UCS)"

        # Check if we're upgrading the Infrastructure package and if the version
        # we're downloading is already running

        # The UCS object returns the version in the standard Cisco presentation
        # of <Major>.<Minor>(<sub release>) -- so have to convert our version
        # number to check!
        Write-Output " UCS Domain Version: $($UCSObj.Version)"
        if ($infra -and $UCSObj.Version -eq ($version -replace '(\d\.\d).(\d[a-z])', '$1($2)') -and !$Force) {
            Write-Output "  This UCS domain is already running $Version. Use the -Force parameter if you wish to force a download."
            Throw
        }
        else {
            Write-Verbose " Requesting NewDownload for Infra bundle"

            # Obtain FI family to select the infrastructure bundle name
            [Int]$InfraBundleNumber = (Get-UcsFirmwareInfraPack).InfraBundleName.Substring(4, 4)
            Write-Verbose "  Detected FI family of $InfraBundleNumber"
            if (NewDownload($FirmwareFilenames.Infrastructure.$InfraBundleNumber)) {
                Write-Output "  Successfully added download task for Infra bundle"
            }
            else {
                Write-Output "  Existing download found; not downloading infrastructure bundle"
            }
        }
        if ($BSeries) {
            Write-Verbose " Requesting NewDownload for B Series bundle"
            if (NewDownload($FirmwareFilenames.BSeries)) {
                Write-Output "  Successfully added download task for B Series bundle"
            }
            else {
                Write-Output "  Existing download found; not downloading B Series bundle"
            }
        }
        if ($CSeries) {
            Write-Verbose " Requesting NewDownload for C Series bundle"
            if (NewDownload($FirmwareFilenames.CSeries)) {
                Write-Output "  Successfully added download task for C Series bundle"
            }
            else {
                Write-Output "  Existing download found; not downloading C Series bundle"
            }
        }
    }
    catch {
        Write-Error " Error with domain $($UCSObj.UCS)"
        Write-Error "$_"
    }
    finally {
        Write-Output "Disconnecting from $($UCSObj.UCS)"
        Disconnect-Ucs -Ucs $UCSObj | Out-Null
    }
}