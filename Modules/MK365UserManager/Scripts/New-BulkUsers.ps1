# Script to create multiple users from a CSV file
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
$users = Import-Csv $CsvPath

# Create users
foreach ($user in $users) {
    try {
        $params = @{
            DisplayName = $user.DisplayName
            UserPrincipalName = $user.UserPrincipalName
            Password = $user.Password
            Department = $user.Department
            JobTitle = $user.JobTitle
            MobilePhone = $user.MobilePhone
        }
        
        if ($user.ForceChangePasswordNextSignIn -eq "TRUE") {
            $params['ForceChangePasswordNextSignIn'] = $true
        }

        if ($WhatIf) {
            Write-Host "Would create user: $($user.UserPrincipalName)"
        }
        else {
            $newUser = New-MK365User @params
            Write-Host "Created user: $($newUser.UserPrincipalName)"
        }
    }
    catch {
        Write-Error "Failed to create user $($user.UserPrincipalName): $_"
    }
}
