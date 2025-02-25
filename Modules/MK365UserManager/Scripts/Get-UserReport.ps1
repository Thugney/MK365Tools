# Script to generate a comprehensive user report
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "UserReport.csv",
    
    [Parameter(Mandatory = $false)]
    [string]$Department,
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeGroups,
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeSecurity
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

# Get all users
$users = Get-MK365UserOverview
if ($Department) {
    $users = $users | Where-Object { $_.Department -eq $Department }
}

# Create report array
$report = @()

foreach ($user in $users) {
    $userReport = [PSCustomObject]@{
        DisplayName = $user.DisplayName
        UserPrincipalName = $user.UserPrincipalName
        Department = $user.Department
        JobTitle = $user.JobTitle
        AccountEnabled = $user.AccountEnabled
        CreatedDateTime = $user.CreatedDateTime
    }

    # Add group information if requested
    if ($IncludeGroups) {
        try {
            $groups = Get-MK365UserGroups -UserPrincipalName $user.UserPrincipalName
            $userReport | Add-Member -NotePropertyName "Groups" -NotePropertyValue ($groups.DisplayName -join "; ")
        }
        catch {
            Write-Warning "Failed to get groups for user $($user.UserPrincipalName): $_"
            $userReport | Add-Member -NotePropertyName "Groups" -NotePropertyValue "Error retrieving groups"
        }
    }

    # Add security information if requested
    if ($IncludeSecurity) {
        try {
            $security = Get-MK365UserSecurityStatus -UserPrincipalName $user.UserPrincipalName
            $userReport | Add-Member -NotePropertyName "RiskLevel" -NotePropertyValue $security.RiskLevel
            $userReport | Add-Member -NotePropertyName "RiskState" -NotePropertyValue $security.RiskState
            $userReport | Add-Member -NotePropertyName "AuthenticationMethods" -NotePropertyValue ($security.AuthenticationMethods.Type -join "; ")
        }
        catch {
            Write-Warning "Failed to get security status for user $($user.UserPrincipalName): $_"
            $userReport | Add-Member -NotePropertyName "SecurityStatus" -NotePropertyValue "Error retrieving security status"
        }
    }

    $report += $userReport
}

# Export report to CSV
$report | Export-Csv -Path $OutputPath -NoTypeInformation
Write-Host "Report exported to $OutputPath"
