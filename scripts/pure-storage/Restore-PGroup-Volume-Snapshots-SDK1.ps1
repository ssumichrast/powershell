<#
    .SYNOPSIS
    Clones all volumes from a specific Protection Group snapshot to new volumes. (SDK1)

    .DESCRIPTION
    This script will create a clone of every volume from an instance of a protection group snapshot.
    Volumes will be restored to the array with a suffix of the snapshot date and time.
    Volumes can then be attached to hosts, copied over existing volumes, added to new protection groups, replicated, or whatever other task required with any standard FlashArray volume.

    Script uses Pure SDK 1

    .PARAMETER Array
    FQDN or IP address of the FlashArray to connect to.

    .PARAMETER PGroupSnapshotName
    The name of the Protection Group snapshot.
    This can be found in the GUI under the Protection Group.
    This can also be found in the CLI via "purepgroup snap <Protection Group name>"

    .EXAMPLE
    PS> .\Restore-PGroup-Volume-Snapshots.ps1 -Array flasharray1.domain.net -PGroupSnapshotName SQL.1503

    .NOTES
    Author: Steve Sumichrast <steven.sumichrast@gmail.com>
#>

#Requires -Module PureStoragePowerShellSDK -Version 5

param(
    [parameter(Mandatory = $true)]
    [string]$Array,
    [parameter(Mandatory = $true)]
    [string]$PGroupSnapshotName
)

# Connect to the array
try {
    $pfa = New-PfaArray -EndPoint $Array -Credential (Get-Credential -Message "FlashArray Administrator Login") -IgnoreCertificateError
}
catch {
    Throw "Failed to log in to Pure Storage FlashArray $($Array)"
}

# Verify the protection group snapshot exists
if ($PGSnapObj = Get-PfaProtectionGroupSnapshots -Array $pfa -Name $PGroupSnapshotName) {
    Write-Host "Found matching protection group. Creating new volumes from snapshot copy."
    $SnapshotDate = $PGSnapObj.Created.ToString("yyyy-MM-ddThh-mm-ss")

    if ($VolumeSnapshots = Get-PfaVolumeSnapshot -Array $pfa -SnapshotName "$($PGSnapObj.Name)*") {
        $output = Foreach ($VolumeSnapshot in $VolumeSnapshots) {
            $NewVolumeName = "$($VolumeSnapshot.Source)-$($SnapshotDate)"
            Write-Host "Creating volume $($NewVolumeName) from snapshot"
            $NewVolumeObject = New-PfaVolume -Array $pfa -VolumeName $NewVolumeName -Source $VolumeSnapshot.Name
            
            # Return an object for formatted output
            [PSCustomObject]@{
                VolumeName   = $NewVolumeObject.Name
                SourceVolume = $VolumeSnapshot.Name

            }
        }
    }
    
    # Return output to the host
    Write-Host "Following new volumes were created from the snapshot $($PGroupSnapshotName) on $($SnapshotDate)"
    $Output | Format-Table -AutoSize
}
else {
    Write-Host -ForegroundColor Red "Error: Could not find a protection group snapshot named $($PGroupSnapshotName)"
}

# Disconnect from the FlashArray
Disconnect-PfaArray -Array $pfa

