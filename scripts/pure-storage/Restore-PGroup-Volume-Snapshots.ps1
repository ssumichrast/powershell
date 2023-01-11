<#
    .SYNOPSIS
    Clones all volumes from a specific Protection Group snapshot to new volumes.

    .DESCRIPTION
    This script will create a clone of every volume from an instance of a protection group snapshot.
    Volumes will be restored to the array with a suffix of the snapshot date and time.
    Volumes can then be attached to hosts, copied over existing volumes, added to new protection groups, replicated, or whatever other task required with any standard FlashArray volume.

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

#Requires -Module PureStoragePowerShellSDK2

param(
    [parameter(Mandatory = $true)]
    [string]$Array,
    [parameter(Mandatory = $true)]
    [string]$PGroupSnapshotName
)

# Connect to the array
try {
    $pfa = Connect-Pfa2Array -Endpoint $Array -Credential (Get-Credential -Message "FlashArray Administrator Login") -IgnoreCertificateError
}
catch {
    Throw "Failed to log in to Pure Storage FlashArray $($Array)"
}

# Verify the protection group snapshot exists
if ($PGSnapObj = Get-Pfa2ProtectionGroupSnapshot -Array $pfa -Name $PGroupSnapshotName) {
    Write-Host "Found matching protection group. Creating new volumes from snapshot copy."
    $SnapshotDate = $PGSnapObj.Created.ToString("yyyy-MM-ddThh-mm-ss")

    if ($VolumeSnapshots = Get-Pfa2VolumeSnapshot -Array $pfa -Name "$($PGSnapObj.Name)*") {
        $output = Foreach ($VolumeSnapshot in $VolumeSnapshots) {
            $NewVolumeName = "$($VolumeSnapshot.Suffix)-$($SnapshotDate)"
            Write-Host "Creating volume $($NewVolumeName) from snapshot"
            $NewVolumeObject = New-Pfa2Volume -Array $pfa -Name $NewVolumeName -SourceId $VolumeSnapshot.Id
            
            # Return an object for formatted output
            [PSCustomObject]@{
                VolumeName   = $NewVolumeObject.Name
                SourceVolume = $NewVolumeObject.Source.Name

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
Disconnect-Pfa2array -Array $pfa

