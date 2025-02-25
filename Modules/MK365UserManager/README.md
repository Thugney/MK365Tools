# MK365UserManager PowerShell Module

A PowerShell module for managing Microsoft 365 users through Microsoft Graph API. This module provides a comprehensive set of functions for user management, group management, and security settings.

## Prerequisites

- PowerShell 5.1 or later
- Microsoft Graph PowerShell SDK modules:
  - Microsoft.Graph.Authentication
  - Microsoft.Graph.Users
  - Microsoft.Graph.Groups
  - Microsoft.Graph.Identity.SignIns

## Installation

1. Clone this repository or download the module files
2. Import the module:
```powershell
Import-Module .\MK365UserManager.psd1
```

## Features

### User Management
- Create, update, and remove users
- Manage user properties and access settings
- Reset passwords and enable MFA
- Bulk user operations with CSV templates
- User access control and permissions
- User security status monitoring
- Automated user provisioning
- User license management
- Custom attribute management
- User activity tracking

### Group Management
- Add and remove users from groups
- View user group memberships
- Bulk group assignments

### Security Management
- Monitor user sign-in status
- Track security and risk levels
- Manage authentication methods
- Enable and configure MFA

### Reporting
- Generate comprehensive user reports
- Track security compliance
- Monitor group memberships
- Schedule automated reports

### Templates and Scripts
The module includes ready-to-use templates and scripts for common operations:

#### Templates
- `NewUsers.csv` - Template for bulk user creation
- `UserGroupAssignments.csv` - Template for group assignments
- `BulkUserUpdate.csv` - Template for updating user properties

#### Scripts
- `New-BulkUsers.ps1` - Create multiple users from CSV
- `Add-BulkUserGroups.ps1` - Assign users to groups in bulk
- `Get-UserReport.ps1` - Generate user and security reports

For detailed information about templates and scripts, see `Templates/README.md`.

## Functions

### Connection Management
- `Connect-MK365User`: Establishes connection to Microsoft Graph API
  ```powershell
  Connect-MK365User -TenantId "your-tenant-id" -Interactive
  ```

### User Management
- `Get-MK365UserOverview`: Retrieves user information
  ```powershell
  Get-MK365UserOverview -UserPrincipalName "user@domain.com" -Detailed
  ```

- `New-MK365User`: Creates a new Microsoft 365 user
  ```powershell
  New-MK365User -DisplayName "John Doe" -UserPrincipalName "john@domain.com" -Password "SecurePass123!" -Department "IT"
  ```

- `Set-MK365UserProperties`: Updates user properties
  ```powershell
  Set-MK365UserProperties -UserPrincipalName "user@domain.com" -DisplayName "New Name" -Department "HR"
  ```

- `Remove-MK365User`: Removes a user
  ```powershell
  Remove-MK365User -UserPrincipalName "user@domain.com"
  ```

### User Management Functions

#### User Creation and Setup
```powershell
# Create a new user
New-MK365User -DisplayName "John Doe" `
              -UserPrincipalName "john.doe@contoso.com" `
              -Password "SecurePass123!" `
              -Department "IT" `
              -JobTitle "Systems Engineer" `
              -ForceChangePasswordNextSignIn

# Update user properties
Set-MK365UserProperties -UserPrincipalName "john.doe@contoso.com" `
                       -DisplayName "John A. Doe" `
                       -Department "IT Infrastructure" `
                       -JobTitle "Senior Systems Engineer"

# Remove a user
Remove-MK365User -UserPrincipalName "john.doe@contoso.com"
```

#### User Access Management
```powershell
# Get user access information
Get-MK365UserAccess -UserPrincipalName "john.doe@contoso.com"

# Set user access
Set-MK365UserAccess -UserPrincipalName "john.doe@contoso.com" `
                    -BlockSignIn $false `
                    -AddDirectoryRoles @("Helpdesk Administrator")

# Get user security status
Get-MK365UserSecurityStatus -UserPrincipalName "john.doe@contoso.com"
```

#### Password and Authentication
```powershell
# Reset user password
Reset-MK365UserPassword -UserPrincipalName "john.doe@contoso.com" `
                       -NewPassword "NewSecurePass123!" `
                       -ForceChangePasswordNextSignIn

# Enable MFA
Enable-MK365MFA -UserPrincipalName "john.doe@contoso.com"
```

#### Bulk Operations
```powershell
# Create multiple users from CSV
$users = Import-Csv ".\Templates\NewUsers.csv"
foreach ($user in $users) {
    New-MK365User @user
}

# Update multiple users
$updates = Import-Csv ".\Templates\BulkUserUpdate.csv"
foreach ($update in $updates) {
    Set-MK365UserProperties @update
}
```

### User Management Templates
The module includes ready-to-use templates for user management:

#### NewUsers.csv
```csv
DisplayName,UserPrincipalName,Password,Department,JobTitle,MobilePhone,ForceChangePasswordNextSignIn
John Doe,john.doe@contoso.com,SecurePass123!,IT,Systems Engineer,+1234567890,TRUE
```

#### BulkUserUpdate.csv
```csv
UserPrincipalName,DisplayName,Department,JobTitle,MobilePhone,AccountEnabled
john.doe@contoso.com,John A. Doe,IT Infrastructure,Senior Systems Engineer,+1234567890,TRUE
```

### User Management Best Practices
1. Always use secure passwords and enable MFA
2. Review user access regularly
3. Document user management procedures
4. Use bulk operations for efficiency
5. Maintain user lifecycle management
6. Regular security audits
7. Monitor user activity

### Group Management
- `Add-MK365UserToGroup`: Adds a user to a group
  ```powershell
  Add-MK365UserToGroup -UserPrincipalName "user@domain.com" -GroupId "group-id"
  ```

- `Remove-MK365UserFromGroup`: Removes a user from a group
  ```powershell
  Remove-MK365UserFromGroup -UserPrincipalName "user@domain.com" -GroupId "group-id"
  ```

- `Get-MK365UserGroups`: Lists groups a user belongs to
  ```powershell
  Get-MK365UserGroups -UserPrincipalName "user@domain.com"
  ```

### Access Management
- `Get-MK365UserAccess`: Retrieves user access information including roles and permissions
  ```powershell
  Get-MK365UserAccess -UserPrincipalName "user@domain.com"
  ```

- `Set-MK365UserAccess`: Manages user access settings including roles and sign-in restrictions
  ```powershell
  Set-MK365UserAccess -UserPrincipalName "user@domain.com" -BlockSignIn $false -AddDirectoryRoles @("User Administrator")
  ```

### Security Management
- `Get-MK365UserSignInStatus`: Retrieves user sign-in status
  ```powershell
  Get-MK365UserSignInStatus -UserPrincipalName "user@domain.com"
  ```

- `Reset-MK365UserPassword`: Resets a user's password
  ```powershell
  Reset-MK365UserPassword -UserPrincipalName "user@domain.com" -NewPassword "NewSecurePass123!" -ForceChangePasswordNextSignIn
  ```

- `Enable-MK365MFA`: Enables Multi-Factor Authentication for a user
  ```powershell
  Enable-MK365MFA -UserPrincipalName "user@domain.com"
  ```

- `Get-MK365UserSecurityStatus`: Retrieves comprehensive security information about a user
  ```powershell
  Get-MK365UserSecurityStatus -UserPrincipalName "user@domain.com"
  ```

## Report Generation

### Basic Reports
```powershell
# Generate basic user report
Get-UserReport.ps1 -OutputPath "Reports\UserReport.csv"

# Include group memberships
Get-UserReport.ps1 -OutputPath "Reports\UserGroups.csv" -IncludeGroups

# Full security audit
Get-UserReport.ps1 -OutputPath "Reports\SecurityAudit.csv" -IncludeGroups -IncludeSecurity
```

### Automated Reports
Schedule regular reports using Windows Task Scheduler:
```powershell
# Create daily report task
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PWD\Scripts\Get-UserReport.ps1`" -OutputPath `"$PWD\Reports\DailyReport.csv`""
$trigger = New-ScheduledTaskTrigger -Daily -At 6AM
Register-ScheduledTask -TaskName "M365 Daily User Report" -Action $action -Trigger $trigger
```

### Report Management
- Reports are generated in the `Reports` directory
- Report files are automatically excluded from git
- Implement your organization's backup and retention policies

## Error Handling

All functions include comprehensive error handling and will:
- Verify Microsoft Graph connection before executing operations
- Provide detailed error messages when operations fail
- Support verbose output for debugging (`-Verbose` parameter)

## Best Practices

1. Always use secure passwords and follow your organization's password policies
2. Use the `-Verbose` parameter when troubleshooting
3. Test operations in a non-production environment first
4. Use `ShouldProcess` support for destructive operations (e.g., `Remove-MK365User -WhatIf`)

## Contributing

Feel free to submit issues and enhancement requests!
