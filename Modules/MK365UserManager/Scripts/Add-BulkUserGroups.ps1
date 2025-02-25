# Script to add users to groups from a CSV file
param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# Import the MK365UserManager module
Import-Module (Join-Path $PSScriptRoot ".." "MK365UserManager.psd1")

# Connect to Microsoft 365
try {
    Connect-MK365User -Interactive
}
catch {
    Write-Error "Failed to connect to Microsoft 365: $_"
    return
}

# Import the CSV file
$assignments = Import-Csv $CsvPath

# Add users to groups
foreach ($assignment in $assignments) {
    $groups = $assignment.GroupIds -split ','
    
    foreach ($groupId in $groups) {
        try {
            if ($WhatIf) {
                Write-Host "Would add user $($assignment.UserPrincipalName) to group $groupId"
            }
            else {
                Add-MK365UserToGroup -UserPrincipalName $assignment.UserPrincipalName -GroupId $groupId.Trim()
                Write-Host "Added user $($assignment.UserPrincipalName) to group $groupId"
            }
        }
        catch {
            Write-Error "Failed to add user $($assignment.UserPrincipalName) to group $groupId`: $_"
        }
    }
}
