# MK365UserManager Templates and Scripts

This directory contains templates and scripts for common operations with the MK365UserManager module.

## Templates

### NewUsers.csv
Template for creating multiple new users in bulk:
- DisplayName: User's full name
- UserPrincipalName: User's email/login
- Password: Initial password
- Department: User's department
- JobTitle: User's job title
- MobilePhone: User's mobile number
- ForceChangePasswordNextSignIn: Whether to force password change

### UserGroupAssignments.csv
Template for assigning users to multiple groups:
- UserPrincipalName: User's email/login
- GroupIds: Comma-separated list of group IDs

### BulkUserUpdate.csv
Template for updating multiple user properties:
- UserPrincipalName: User's email/login
- DisplayName: Updated full name
- Department: Updated department
- JobTitle: Updated job title
- MobilePhone: Updated mobile number
- AccountEnabled: Account status

## Scripts

### New-BulkUsers.ps1
Creates multiple users from a CSV file:
```powershell
.\New-BulkUsers.ps1 -CsvPath "NewUsers.csv" -WhatIf
.\New-BulkUsers.ps1 -CsvPath "NewUsers.csv"
```

### Add-BulkUserGroups.ps1
Adds users to groups based on CSV assignments:
```powershell
.\Add-BulkUserGroups.ps1 -CsvPath "UserGroupAssignments.csv" -WhatIf
.\Add-BulkUserGroups.ps1 -CsvPath "UserGroupAssignments.csv"
```

### Get-UserReport.ps1
Generates a comprehensive user report:
```powershell
# Basic report
.\Get-UserReport.ps1 -OutputPath "UserReport.csv"

# Report with group memberships
.\Get-UserReport.ps1 -OutputPath "UserReport.csv" -IncludeGroups

# Report with security information for IT department
.\Get-UserReport.ps1 -OutputPath "ITUsers.csv" -Department "IT" -IncludeGroups -IncludeSecurity
```

## Reports

Reports are generated dynamically when you run the reporting scripts. The following reports can be generated:

### User Overview Report
Generated by `Get-UserReport.ps1`, includes:
- Basic user information (name, email, department)
- Account status
- Group memberships (optional)
- Security status (optional)

Example report fields:
```
DisplayName,UserPrincipalName,Department,JobTitle,AccountEnabled,CreatedDateTime,Groups,RiskLevel,RiskState,AuthenticationMethods
John Doe,john.doe@contoso.com,IT,Systems Engineer,True,2024-02-25,IT Staff; VPN Users,Low,None,microsoftAuthenticator
```

To generate reports:
```powershell
# Basic user report
.\Scripts\Get-UserReport.ps1 -OutputPath "Reports\UserReport.csv"

# Department-specific report with group memberships
.\Scripts\Get-UserReport.ps1 -OutputPath "Reports\IT_Users.csv" -Department "IT" -IncludeGroups

# Full security report
.\Scripts\Get-UserReport.ps1 -OutputPath "Reports\SecurityAudit.csv" -IncludeGroups -IncludeSecurity
```

### Report Scheduling
You can schedule regular report generation using Windows Task Scheduler:

```powershell
# Create a scheduled task to generate daily reports
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PWD\Scripts\Get-UserReport.ps1`" -OutputPath `"$PWD\Reports\DailyReport.csv`" -IncludeGroups"

$trigger = New-ScheduledTaskTrigger -Daily -At 6AM
Register-ScheduledTask -TaskName "M365 Daily User Report" -Action $action -Trigger $trigger
```

### Report Location
By default, reports are saved in the current directory. We recommend:
1. Creating a `Reports` directory to store generated reports
2. Adding `Reports/*` to your `.gitignore` to prevent committing sensitive data
3. Backing up reports according to your organization's retention policy

## Usage Examples

1. Create multiple users:
```powershell
# 1. Edit NewUsers.csv with your user data
# 2. Test the creation process
.\Scripts\New-BulkUsers.ps1 -CsvPath ".\Templates\NewUsers.csv" -WhatIf
# 3. Create the users
.\Scripts\New-BulkUsers.ps1 -CsvPath ".\Templates\NewUsers.csv"
```

2. Assign users to groups:
```powershell
# 1. Edit UserGroupAssignments.csv with your assignments
# 2. Test the assignments
.\Scripts\Add-BulkUserGroups.ps1 -CsvPath ".\Templates\UserGroupAssignments.csv" -WhatIf
# 3. Make the assignments
.\Scripts\Add-BulkUserGroups.ps1 -CsvPath ".\Templates\UserGroupAssignments.csv"
```

3. Generate reports:
```powershell
# Generate full report with groups and security
.\Scripts\Get-UserReport.ps1 -OutputPath "FullReport.csv" -IncludeGroups -IncludeSecurity

# Generate department-specific report
.\Scripts\Get-UserReport.ps1 -OutputPath "HR_Report.csv" -Department "HR" -IncludeGroups
```

## Best Practices

1. Always use `-WhatIf` first when running bulk operations
2. Review CSV files before running scripts
3. Keep a backup of the reports
4. Run scripts from the module's root directory
5. Test with a small subset of users first
