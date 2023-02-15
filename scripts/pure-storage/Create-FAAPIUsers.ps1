#Requires -Version 7.3
#Requires -Modules PureStoragePowerShellSDK2

<#
    .SYNOPSIS
    Creates a local user and API token for arrays specified

    .DESCRIPTION
    For each array listed (endpoints), creates a local user account with the user-provided password.
    Generates an API Token for each account and provides the full list of arrays and accounts created at the end.
    Account is created with "readonly" role. Can be overriden to other support roles on FlashArray.

    .PARAMETER endpoints
    One or more IP addresses or FQDNs to a FlashArray management interface, separated by commas

    .PARAMETER APIRole
    Specifies which level of access to grant the account.
    Default: readonly
 
    .EXAMPLE
    .\Create-FAAPIUsers.ps1 -Endpoints flasharray1.testdrive.local
    Script will prompt for array administrator account login credentials and then for the username/password of the API account to create.

    Output:

    Following API Users and Tokens were created:

    Array             APIUser APIRole  APIToken
    -----             ------- -------  --------
    flasharray1       api1    readonly 7b266479-d602-58f8-6045-48044a13c06d

    .NOTES
    Author: Steve Sumichrast <steven.sumichrast@gmail.com>
#>

param(
    [parameter(Mandatory = $true)]
    [string[]]$endpoints,
    [ValidateSet("array_admin", "storage_admin", "ops_admin", "readonly")]
    [string]$APIRole = "readonly"
)

# Get admin credentials for FlashArray
$AdminCredentials = Get-Credential -Message "FlashArray Administrator Login"

# Get API User info
$APIUserCredentials = Get-Credential -Message "Username and Password to Create"

# Create api user on each array provided
$output = foreach ($endpoint in $endpoints) {
    # Connect to array
    try {
        $PFAObj = Connect-Pfa2Array -Endpoint $endpoint -Credential $AdminCredentials -IgnoreCertificateError
    }
    catch {
        throw "Failed to login to array "
    }

    # Attempt to create a new user and API token
    try {
        Write-Verbose " $($endpoint): Creating API user and obtaining token"
        # Create new array user
        $APIUser = New-Pfa2Admin -Array $PFAObj -Name $APIUserCredentials.Username -Password $APIUserCredentials.Password -RoleName $APIRole

        # Create API User Token
        $APIUserToken = New-Pfa2AdminApiToken -Array $PFAObj -Name $APIUser.Name

        # Format output
        [PSCustomObject]@{
            Array    = $(get-pfa2array -array $PFAObj).name
            APIUser  = $APIUser.name
            APIRole  = $APIUser.role.Name
            APIToken = $APIUserToken.ApiToken.Token
        }
    }
    catch {
        throw " $($endpoint): Failed to create user or obtain token. Verify account does not exist before starting and that name is valid."
    }

    # Disconnect from FA
    Disconnect-Pfa2Array -Array $PFAObj
}


Write-Output "Following API Users and Tokens were created:"

$output | Format-Table -AutoSize | Out-String